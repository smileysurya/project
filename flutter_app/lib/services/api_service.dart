import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator: 10.0.2.2  |  Real device: 192.168.0.102  |  Production: your domain
  static const String baseUrl = 'http://192.168.0.102:5000/api';

  // ─── Users ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerUser({
    required String userId,
    required String name,
    String email = '',
    String phone = '',
    String language = 'en',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId, 'name': name,
          'email': email, 'phone': phone, 'language': language,
        }),
      ).timeout(const Duration(seconds: 10));
      return json.decode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<bool> isUserOnline(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/online'),
      ).timeout(const Duration(seconds: 5));
      final data = json.decode(response.body);
      return data['isOnline'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── Calls ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> startCall({
    required String callerId,
    required String receiverId,
    String callerName = '',
    String receiverName = '',
    String callerLang = 'en',
    String receiverLang = 'en',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/calls/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'callerId': callerId, 'receiverId': receiverId,
          'callerName': callerName, 'receiverName': receiverName,
          'callerLang': callerLang, 'receiverLang': receiverLang,
        }),
      ).timeout(const Duration(seconds: 10));
      return json.decode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> endCall(String callId, int duration) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/calls/end'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'callId': callId, 'duration': duration}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<List<dynamic>> getCallHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/calls/history?userId=$userId'),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      return data['calls'] ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getTranscript(String callId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/calls/$callId/transcript'),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      return data['messages'] ?? [];
    } catch (_) {
      return [];
    }
  }

  // ─── Translation ─────────────────────────────────────────────────────────────
  Future<String> translate(String text, String sourceLang, String targetLang) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/translation/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text, 'sourceLang': sourceLang, 'targetLang': targetLang,
        }),
      ).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body);
      return data['translatedText'] ?? text;
    } catch (_) {
      return text;
    }
  }

  // ─── Speech-to-Text ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> speechToText(Uint8List audioBytes, {String? language}) async {
    try {
      final uri = Uri.parse('$baseUrl/speech/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'audio.wav'));
      if (language != null) request.fields['language'] = language;
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return json.decode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ─── TTS ─────────────────────────────────────────────────────────────────────
  Future<String> textToSpeech(String text, String language) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tts/synthesize'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text, 'language': language}),
      ).timeout(const Duration(seconds: 15));
      final data = json.decode(response.body);
      return data['audioBase64'] ?? '';
    } catch (_) {
      return '';
    }
  }

  // ─── AI ──────────────────────────────────────────────────────────────────────
  Future<String> generateAIResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/generate-response'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 20));
      final data = json.decode(response.body);
      return data['response'] ?? 'Sorry, I couldn\'t generate a response.';
    } catch (_) {
      return 'AI connection error.';
    }
  }
}
