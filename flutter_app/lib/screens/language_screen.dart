import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  static const _languages = {
    'en': ('🇺🇸', 'English'),
    'ta': ('🇮🇳', 'Tamil'),
    'hi': ('🇮🇳', 'Hindi'),
    'es': ('🇪🇸', 'Spanish'),
    'fr': ('🇫🇷', 'French'),
    'de': ('🇩🇪', 'German'),
    'ja': ('🇯🇵', 'Japanese'),
    'zh': ('🇨🇳', 'Chinese'),
    'ar': ('🇸🇦', 'Arabic'),
    'ko': ('🇰🇷', 'Korean'),
    'pt': ('🇧🇷', 'Portuguese'),
    'ru': ('🇷🇺', 'Russian'),
    'it': ('🇮🇹', 'Italian'),
    'tr': ('🇹🇷', 'Turkish'),
    'nl': ('🇳🇱', 'Dutch'),
  };

  late String _myLang;
  late String _targetLang;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _myLang = appState.myLanguage;
    _targetLang = appState.targetLanguage;
  }

  Future<void> _save() async {
    context.read<AppState>().setLanguages(_myLang, _targetLang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('myLanguage', _myLang);
    await prefs.setString('targetLanguage', _targetLang);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Language settings saved ✓'),
          backgroundColor: Color(0xFF6C63FF)));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Language (what you speak)',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            _buildLangGrid(
              selected: _myLang,
              onSelect: (l) => setState(() => _myLang = l),
            ),
            const SizedBox(height: 28),
            const Text('Default Translation Language',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            _buildLangGrid(
              selected: _targetLang,
              onSelect: (l) => setState(() => _targetLang = l),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangGrid({required String selected, required Function(String) onSelect}) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _languages.entries.map((e) {
        final isSelected = selected == e.key;
        final (flag, name) = e.value;
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                ? const Color(0xFF6C63FF)
                : const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                  ? const Color(0xFF6C63FF)
                  : Colors.white12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
