import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/language_screen.dart';
import 'screens/history_screen.dart';
import 'screens/voice_assistant_screen.dart';
import 'screens/message_translation_screen.dart';
import 'screens/test_translation_screen.dart';
import 'services/socket_service.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        Provider(create: (_) => ApiService()),
      ],
      child: const MyApp(),
    ),
  );
}

// ─── Global App State ─────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  String userId = '';
  String userName = '';
  String userEmail = '';
  String myLanguage = 'en';
  String targetLanguage = 'en';
  bool isLoggedIn = false;

  // Incoming call state
  String? incomingCallId;
  String? incomingCallerId;
  String? incomingCallerName;
  String? incomingCallerLang;

  void login(String id, String name, String email, String lang) {
    userId = id;
    userName = name;
    userEmail = email;
    myLanguage = lang;
    isLoggedIn = true;
    notifyListeners();
  }

  void setLanguages(String mine, String target) {
    myLanguage = mine;
    targetLanguage = target;
    notifyListeners();
  }

  void setIncomingCall({
    required String callId,
    required String callerId,
    required String callerName,
    required String callerLang,
  }) {
    incomingCallId = callId;
    incomingCallerId = callerId;
    incomingCallerName = callerName;
    incomingCallerLang = callerLang;
    notifyListeners();
  }

  void clearIncomingCall() {
    incomingCallId = null;
    incomingCallerId = null;
    incomingCallerName = null;
    incomingCallerLang = null;
    notifyListeners();
  }

  void logout() {
    userId = '';
    userName = '';
    userEmail = '';
    isLoggedIn = false;
    notifyListeners();
  }

  void updateFromJson(Map<String, dynamic> json) {
    userId = json['userId'] ?? '';
    userName = json['userName'] ?? '';
    myLanguage = json['myLanguage'] ?? 'en';
    targetLanguage = json['targetLanguage'] ?? 'en';
    isLoggedIn = true;
    notifyListeners();
  }
}

// ─── App Widget ───────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Voice Translator',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: '/login',
      onGenerateRoute: _generateRoute,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F1117),
      cardColor: const Color(0xFF1A1D27),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1D27),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252840),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white60),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Route? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/voice':
        return MaterialPageRoute(builder: (_) => const VoiceAssistantScreen());
      case '/contacts':
        return MaterialPageRoute(builder: (_) => const ContactsScreen());
      case '/call':
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => CallScreen(callArgs: args));
      case '/incoming_call':
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => IncomingCallScreen(callArgs: args));
      case '/message':
        return MaterialPageRoute(builder: (_) => const MessageTranslationScreen());
      case '/history':
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case '/test':
        return MaterialPageRoute(builder: (_) => const TestTranslationScreen());
      case '/language':
        return MaterialPageRoute(builder: (_) => const LanguageScreen());
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}
