import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class MessageTranslationScreen extends StatefulWidget {
  const MessageTranslationScreen({super.key});

  @override
  State<MessageTranslationScreen> createState() => _MessageTranslationScreenState();
}

class _MessageTranslationScreenState extends State<MessageTranslationScreen> {
  final _textCtrl = TextEditingController();
  String? _translatedText;
  String? _aiReply;
  bool _loading = false;
  late AudioService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _audioService.init();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _translatedText = null;
      _aiReply = null;
    });

    final api = context.read<ApiService>();
    final appState = context.read<AppState>();

    try {
      final res = await api.translate(text, appState.myLanguage, appState.targetLanguage);
      setState(() => _translatedText = res);
    } catch (e) {
      debugPrint("Translation error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _getAIReply() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);
    final api = context.read<ApiService>();

    try {
      final res = await api.generateAIResponse(text);
      setState(() => _aiReply = res);
    } catch (e) {
      debugPrint("AI Reply error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _playTTS(String text, String lang) async {
    final api = context.read<ApiService>();
    final audioBase64 = await api.textToSpeech(text, lang);
    if (audioBase64.isNotEmpty) {
      await _audioService.playBase64Audio(audioBase64);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Translate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Box
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   Row(
                    children: [
                      Text(appState.myLanguage.toUpperCase(), 
                        style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 12)),
                      const Icon(Icons.arrow_right, color: Colors.white24),
                      Text(appState.targetLanguage.toUpperCase(),
                        style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  TextField(
                    controller: _textCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: 'Type something to translate...',
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _translate,
                    icon: const Icon(Icons.translate, size: 18),
                    label: const Text('Translate'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _getAIReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withOpacity(0.15),
                      foregroundColor: Colors.amber,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.auto_awesome),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),

            // Translation Result
            if (_translatedText != null) ...[
              const Text('TRANSLATION', 
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildResultCard(_translatedText!, appState.targetLanguage, Colors.tealAccent),
              const SizedBox(height: 24),
            ],

            // AI Reply Result
            if (_aiReply != null) ...[
              const Text('AI SUGGESTION', 
                style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildResultCard(_aiReply!, appState.myLanguage, Colors.amber),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String text, String lang, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.4)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _IconButton(icon: Icons.copy, color: Colors.white38, onTap: () => _copy(text)),
              const SizedBox(width: 16),
              _IconButton(icon: Icons.volume_up, color: accentColor, onTap: () => _playTTS(text, lang)),
            ],
          )
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
