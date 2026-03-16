import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with TickerProviderStateMixin {
  late AudioService _audioService;
  bool _isRecording = false;
  String? _originalText;
  String? _translatedText;
  String? _aiReply;
  bool _loading = false;
  String _status = 'Tap mic to speak';
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _audioService.init();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _audioService.stopRecording();
      _pulseController.stop();
      _waveController.stop();
      setState(() {
        _isRecording = false;
        _status = 'Processing...';
      });
    } else {
      setState(() {
        _isRecording = true;
        _originalText = null;
        _translatedText = null;
        _aiReply = null;
        _status = 'Listening...';
      });
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      
      final appState = context.read<AppState>();
      final api = context.read<ApiService>();

      await _audioService.startContinuousRecording(
        onChunk: (bytes) async {
          if (!mounted) return;
          setState(() => _status = 'Transcribing...');
          try {
            final stt = await api.speechToText(bytes, language: appState.myLanguage);
            final text = stt['text'] ?? '';
            if (text.isEmpty) {
              setState(() => _status = 'Done (No speech detected)');
              return;
            }

            setState(() {
              _originalText = text;
              _status = 'Translating...';
            });

            final translated = await api.translate(text, appState.myLanguage, appState.targetLanguage);
            setState(() {
              _translatedText = translated;
              _status = 'Playing...';
            });

            final audioBase64 = await api.textToSpeech(translated, appState.targetLanguage);
            if (audioBase64.isNotEmpty) {
              await _audioService.playBase64Audio(audioBase64);
            }
            setState(() => _status = 'Done! Tap mic to speak again.');
          } catch (e) {
            setState(() => _status = 'Error: $e');
          }
        },
      );
    }
  }

  Future<void> _generateAIReply() async {
    if (_originalText == null || _originalText!.isEmpty) return;
    setState(() {
      _loading = true;
      _status = 'Generating AI reply...';
    });
    final api = context.read<ApiService>();
    try {
      final reply = await api.generateAIResponse(_originalText!);
      setState(() => _aiReply = reply);
      
      final appState = context.read<AppState>();
      final audioBase64 = await api.textToSpeech(reply, appState.myLanguage);
      if (audioBase64.isNotEmpty) {
        await _audioService.playBase64Audio(audioBase64);
      }
      setState(() => _status = 'Done!');
    } catch (e) {
      setState(() => _status = 'AI Error');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/language'),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Language Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(appState.myLanguage.toUpperCase(), 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.swap_horiz, color: Colors.white24),
                  ),
                  Text(appState.targetLanguage.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            
            // Interaction Cards
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_originalText != null) 
                      _buildResultCard("You said", _originalText!, const Color(0xFF6C63FF).withOpacity(0.15), const Color(0xFF6C63FF)),
                    
                    if (_translatedText != null)
                      _buildResultCard("Translated", _translatedText!, Colors.tealAccent.withOpacity(0.1), Colors.tealAccent),
                    
                    if (_aiReply != null)
                      _buildResultCard("AI Assistant", _aiReply!, Colors.amber.withOpacity(0.1), Colors.amber),
                      
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      ),
                  ],
                ),
              ),
            ),

            if (_isRecording) 
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildWaveform(),
              ),

            // AI Reply Button
            if (_originalText != null && _aiReply == null && !_loading && !_isRecording)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ElevatedButton.icon(
                  onPressed: _generateAIReply,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text("Get AI Suggestion"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    foregroundColor: Colors.amber,
                  ),
                ),
              ),

            // Recording Button
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: ScaleTransition(
                      scale: _isRecording ? _pulseController.drive(Tween(begin: 1.0, end: 1.15)) : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.redAccent : const Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.redAccent : const Color(0xFF6C63FF)).withOpacity(0.4),
                              blurRadius: 20, spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white, size: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? "Listening..." : "Tap to speak",
                    style: TextStyle(
                      color: _isRecording ? Colors.redAccent : Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            final h = 5 + (20 * (0.5 + 0.5 * (index % 2 == 0 ? (index+1)/5 : 1 - (index+1)/5) * (0.5 + 0.5 * (index+1)/5)));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: _isRecording ? h : 4,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildResultCard(String label, String content, Color bgColor, Color accentColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              const Icon(Icons.volume_up, size: 16, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4)),
        ],
      ),
    );
  }
}
