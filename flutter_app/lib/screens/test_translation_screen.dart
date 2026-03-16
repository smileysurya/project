import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class TestTranslationScreen extends StatefulWidget {
  const TestTranslationScreen({super.key});

  @override
  State<TestTranslationScreen> createState() => _TestTranslationScreenState();
}

class _TestTranslationScreenState extends State<TestTranslationScreen> {
  late AudioService _audioService;
  bool _isRecording = false;
  final List<TestEntry> _entries = [];
  String _status = 'Tap to start solo test';
  String _myLang = 'en';
  String _targetLang = 'ta';

  static const _langs = {
    'en': '🇺🇸 EN', 'ta': '🇮🇳 TA', 'hi': '🇮🇳 HI',
    'es': '🇪🇸 ES', 'fr': '🇫🇷 FR', 'de': '🇩🇪 DE',
    'ja': '🇯🇵 JA', 'zh': '🇨🇳 ZH', 'ar': '🇸🇦 AR',
  };

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _audioService.init();
    final appState = context.read<AppState>();
    _myLang = appState.myLanguage;
    _targetLang = appState.targetLanguage;
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleSoloTest() async {
    if (_isRecording) {
      await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
        _status = 'Stopped';
      });
    } else {
      setState(() {
        _isRecording = true;
        _status = 'Listening...';
      });
      
      final api = context.read<ApiService>();

      await _audioService.startContinuousRecording(
        onChunk: (bytes) async {
          if (!mounted) return;
          try {
            final stt = await api.speechToText(bytes, language: _myLang);
            final text = stt['text'] ?? '';
            if (text.isEmpty) return;

            setState(() {
              _entries.insert(0, TestEntry(text: text, type: 'original'));
            });

            final translated = await api.translate(text, _myLang, _targetLang);
            setState(() {
              _entries.insert(0, TestEntry(text: translated, type: 'translated'));
            });

            final audioBase64 = await api.textToSpeech(translated, _targetLang);
            if (audioBase64.isNotEmpty) {
              await _audioService.playBase64Audio(audioBase64);
            }
          } catch (e) {
            debugPrint("Solo test error: $e");
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solo Translation Test')),
      body: Column(
        children: [
          // Select languages
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(child: _buildLangDropdown('Speak in', _myLang, (v) => setState(() => _myLang = v!))),
                const Icon(Icons.arrow_forward, color: Colors.white24, size: 20),
                Expanded(child: _buildLangDropdown('Translate to', _targetLang, (v) => setState(() => _targetLang = v!))),
              ],
            ),
          ),
          
          Text(_status, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (_, i) => _buildEntryBubble(_entries[i]),
            ),
          ),
          
          // Test button
          Padding(
            padding: const EdgeInsets.all(32),
            child: FloatingActionButton.extended(
              onPressed: _toggleSoloTest,
              backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFF6C63FF),
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Test' : 'Start Solo Test'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangDropdown(String label, String value, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1D27),
          items: _langs.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildEntryBubble(TestEntry entry) {
    final isOriginal = entry.type == 'original';
    return Align(
      alignment: isOriginal ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOriginal ? const Color(0xFF6C63FF).withOpacity(0.1) : const Color(0xFF252840),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOriginal ? const Color(0xFF6C63FF).withOpacity(0.3) : Colors.tealAccent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: isOriginal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(isOriginal ? 'You said' : 'Translation', style: TextStyle(color: isOriginal ? const Color(0xFF6C63FF) : Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(entry.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class TestEntry {
  final String text;
  final String type;
  TestEntry({required this.text, required this.type});
}
