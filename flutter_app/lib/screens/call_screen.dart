import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../main.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';
import '../services/api_service.dart';
import '../models/contact_model.dart';

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> callArgs;
  const CallScreen({super.key, required this.callArgs});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late SocketService _ws;
  late ApiService _api;
  final AudioService _audio = AudioService();
  final FlutterTts _tts = FlutterTts();
  final ScrollController _scrollCtrl = ScrollController();

  // Call args
  String get callId => widget.callArgs['callId'] ?? '';
  bool get isCaller => widget.callArgs['isCaller'] == true;
  String get contactName => widget.callArgs['contactName'] ?? 'Unknown';
  String get contactId => widget.callArgs['contactId'] ?? '';
  String get myLang => widget.callArgs['myLang'] ?? 'en';
  String get contactLang => widget.callArgs['contactLang'] ?? 'en';

  // State
  bool _inCall = false;
  bool _isRecording = false;
  bool _isMuted = false;
  bool _speakerOn = true;
  bool _callConnected = false;
  String _callStatus = 'Connecting...';
  int _callSeconds = 0;
  Timer? _timer;
  DateTime? _callStartTime;

  // Subtitles transcript
  final List<SubtitleEntry> _subtitles = [];

  @override
  void initState() {
    super.initState();
    _ws = context.read<SocketService>();
    _api = context.read<ApiService>();
    _setupSocketCallbacks();
    _audio.init();
    _initCall();
  }

  void _initCall() {
    if (isCaller) {
      setState(() => _callStatus = 'Ringing...');
      // Caller waits for accept
      _ws.onCallAccepted = (id) {
        if (id != callId) return;
        _onCallConnected();
      };
      _ws.onCallRejected = (id) {
        if (id != callId) return;
        if (mounted) {
          setState(() => _callStatus = 'Call declined');
          Future.delayed(
            const Duration(seconds: 2),
            () => Navigator.pop(context),
          );
        }
      };
      _ws.onCallFailed = (id, reason) {
        if (id != callId) return;
        if (mounted) {
          setState(() => _callStatus = reason);
          Future.delayed(
            const Duration(seconds: 2),
            () => Navigator.pop(context),
          );
        }
      };
    } else {
      // Receiver: call already accepted, start immediately
      _onCallConnected();
    }

    _ws.onCallEnded = (id, endedBy, duration) {
      if (id != callId) return;
      _handleCallEnded();
    };
  }

  void _onCallConnected() {
    setState(() {
      _callConnected = true;
      _callStatus = 'Connected';
      _inCall = true;
    });
    _callStartTime = DateTime.now();
    _startTimer();
    _startRecording();
  }

  void _setupSocketCallbacks() {
    final appState = context.read<AppState>();

    // Received translated audio from other party
    _ws.onTranslatedAudio =
        (cId, senderId, original, translated, srcLang, tgtLang, audioB64) {
          if (cId != callId) return;
          final entry = SubtitleEntry(
            callId: cId,
            senderId: senderId,
            speakerName: contactName,
            originalText: original,
            translatedText: translated,
            sourceLang: srcLang,
            targetLang: tgtLang,
            timestamp: DateTime.now(),
            isSelf: false,
          );
          setState(() => _subtitles.add(entry));
          _scrollToBottom();

          // Play audio or TTS
          if (audioB64.isNotEmpty && !_isMuted) {
            _audio.playBase64Audio(audioB64);
          } else if (translated.isNotEmpty && !_isMuted) {
            _tts.speak(translated);
          }
        };

    // Own speech transcribed
    _ws.onOwnTranscript = (cId, original, detectedLang) {
      if (cId != callId) return;
      final entry = SubtitleEntry(
        callId: cId,
        senderId: appState.userId,
        speakerName: 'You',
        originalText: original,
        translatedText: '...',
        sourceLang: detectedLang,
        targetLang: contactLang,
        timestamp: DateTime.now(),
        isSelf: true,
      );
      setState(() => _subtitles.add(entry));
      _scrollToBottom();
    };

    // Subtitle update (updates translated text for own entries)
    _ws.onSubtitleUpdate = (data) {
      if (data['callId'] != callId) return;
      final appUserId = appState.userId;
      if (data['senderId'] == appUserId) {
        // Find last own entry and update translated text
        for (int i = _subtitles.length - 1; i >= 0; i--) {
          if (_subtitles[i].isSelf && _subtitles[i].translatedText == '...') {
            setState(() {
              // Replace with updated subtitle
            });
            break;
          }
        }
      }
    };

    _ws.onTranslationError = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation error: $msg'),
          backgroundColor: Colors.redAccent,
        ),
      );
    };
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isMuted) return;
    setState(() => _isRecording = true);
    final appState = context.read<AppState>();

    await _audio.startContinuousRecording(
      onChunk: (bytes) {
        _ws.sendAudioChunk(bytes, myLang, contactLang);
      },
    );
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    await _audio.stopRecording();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_isMuted) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callSeconds++);
    });
  }

  String get _formattedDuration {
    final m = _callSeconds ~/ 60;
    final s = _callSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await _stopRecording();
    final appState = context.read<AppState>();
    _ws.endCall(callId, appState.userId);
    await _api.endCall(callId, _callSeconds);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  void _handleCallEnded() {
    _timer?.cancel();
    _stopRecording();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call ended')));
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.dispose();
    _tts.stop();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D1A),
        body: SafeArea(
          child: Column(
            children: [
              _buildCallHeader(),
              _buildSubtitlesArea(),
              _buildLangIndicator(),
              _buildCallControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
            child: Text(
              contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contactName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _callConnected
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _callConnected ? _formattedDuration : _callStatus,
                      style: TextStyle(
                        color: _callConnected
                            ? Colors.white70
                            : Colors.orangeAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesArea() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: _subtitles.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.subtitles_outlined,
                      size: 48,
                      color: Colors.white12,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Live subtitles will appear here',
                      style: TextStyle(color: Colors.white24, fontSize: 14),
                    ),
                    if (_callConnected) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Start speaking...',
                        style: TextStyle(color: Colors.white12, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: _subtitles.length,
                itemBuilder: (_, i) => _buildSubtitleBubble(_subtitles[i]),
              ),
      ),
    );
  }

  Widget _buildSubtitleBubble(SubtitleEntry entry) {
    final isSelf = entry.isSelf;
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelf
              ? const Color(0xFF6C63FF).withOpacity(0.25)
              : const Color(0xFF252840),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isSelf
                ? const Radius.circular(14)
                : const Radius.circular(4),
            bottomRight: isSelf
                ? const Radius.circular(4)
                : const Radius.circular(14),
          ),
          border: Border.all(
            color: isSelf
                ? const Color(0xFF6C63FF).withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speaker name + lang
            Row(
              children: [
                Text(
                  entry.speakerName,
                  style: TextStyle(
                    color: isSelf ? const Color(0xFF9C97FF) : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entry.sourceLang} → ${entry.targetLang}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Original text
            Text(
              entry.originalText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            // Translation
            if (entry.translatedText.isNotEmpty &&
                entry.translatedText != '...') ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.translatedText,
                  style: TextStyle(
                    color: isSelf ? const Color(0xFFB8B4FF) : Colors.tealAccent,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ] else if (entry.translatedText == '...') ...[
              const SizedBox(height: 4),
              const Text(
                'Translating...',
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
            // Timestamp
            const SizedBox(height: 4),
            Text(
              '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _langChip(myLang, 'You', const Color(0xFF6C63FF)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, color: Colors.white30, size: 20),
          ),
          _langChip(contactLang, contactName, Colors.teal),
        ],
      ),
    );
  }

  Widget _langChip(String lang, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label · ${lang.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlBtn(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Unmute' : 'Mute',
            color: _isMuted ? Colors.redAccent : Colors.white54,
            onTap: _toggleMute,
          ),
          // End call
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent,
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
          _controlBtn(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            label: _speakerOn ? 'Speaker' : 'Earpiece',
            color: _speakerOn ? Colors.white54 : Colors.white30,
            onTap: _toggleSpeaker,
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D27),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
