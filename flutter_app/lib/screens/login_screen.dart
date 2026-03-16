import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  String _selectedLang = 'en';
  bool _loading = false;

  static const _langs = {
    'en': '🇺🇸 English', 'ta': '🇮🇳 Tamil', 'hi': '🇮🇳 Hindi',
    'es': '🇪🇸 Spanish', 'fr': '🇫🇷 French', 'de': '🇩🇪 German',
    'ja': '🇯🇵 Japanese', 'zh': '🇨🇳 Chinese', 'ar': '🇸🇦 Arabic',
    'ko': '🇰🇷 Korean', 'pt': '🇧🇷 Portuguese', 'ru': '🇷🇺 Russian',
  };

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('userId');
    final savedName = prefs.getString('userName');
    final savedLang = prefs.getString('myLanguage') ?? 'en';
    if (savedId != null && savedName != null && mounted) {
      final appState = context.read<AppState>();
      appState.login(savedId, savedName, '', savedLang);
      _connectSocket(savedId, savedName, savedLang);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    final idInput = _idCtrl.text.trim();
    if (name.isEmpty || idInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and ID')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final userId = idInput.replaceAll(' ', '_');
      final api = context.read<ApiService>();
      await api.registerUser(
        userId: userId, name: name, phone: idInput, language: _selectedLang,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('userName', name);
      await prefs.setString('myLanguage', _selectedLang);

      if (!mounted) return;
      context.read<AppState>().login(userId, name, '', _selectedLang);
      _connectSocket(userId, name, _selectedLang);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _connectSocket(String userId, String name, String lang) {
    final ws = context.read<SocketService>();
    ws.connect();
    Future.delayed(const Duration(milliseconds: 500), () {
      ws.registerUser(userId, name, lang);
      // Listen for incoming calls globally
      ws.onIncomingCall = (callId, callerId, callerName, callerLang) {
        if (!mounted) return;
        context.read<AppState>().setIncomingCall(
          callId: callId, callerId: callerId,
          callerName: callerName, callerLang: callerLang,
        );
        Navigator.pushNamed(context, '/incoming_call', arguments: {
          'callId': callId, 'callerId': callerId,
          'callerName': callerName, 'callerLang': callerLang,
        });
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Column(children: [
                  Text('🌐', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 12),
                  Text('AI Voice Translator',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 6),
                  Text('Real-time translation during calls',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 48),
              const Text('Your Name', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Your ID (phone number or any username)', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _idCtrl,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. +91 98765 43210 or surya_test',
                  prefixIcon: Icon(Icons.badge_outlined, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Your Language', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252840),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF252840),
                    style: const TextStyle(color: Colors.white),
                    items: _langs.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedLang = v!),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
