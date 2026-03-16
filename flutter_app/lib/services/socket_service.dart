import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends ChangeNotifier {
  IO.Socket? _socket;
  bool isConnected = false;

  String? currentCallId;
  String? currentUserId;

  // ─── Callbacks ──────────────────────────────────────────────────────────────
  // Incoming call notification
  Function(String callId, String callerId, String callerName, String callerLang)? onIncomingCall;

  // Call state
  Function(String callId)? onCallAccepted;
  Function(String callId)? onCallRejected;
  Function(String callId, String reason)? onCallFailed;
  Function(String callId, String endedBy, int duration)? onCallEnded;
  Function(String callId)? onCallStarted;
  Function(String callId)? onCallRinging;

  // WebRTC signaling
  Function(String callId, dynamic sdp)? onWebRtcOffer;
  Function(String callId, dynamic sdp)? onWebRtcAnswer;
  Function(String callId, dynamic candidate)? onWebRtcIce;

  // Translation pipeline
  Function(String callId, String senderId, String original, String translated,
      String srcLang, String tgtLang, String audioB64)? onTranslatedAudio;
  Function(String callId, String originalText, String detectedLang)? onOwnTranscript;

  // Subtitles
  Function(Map<String, dynamic> subtitle)? onSubtitleUpdate;

  // Errors
  Function(String message)? onError;
  Function(String message)? onTranslationError;

  // ─── Server URL ─────────────────────────────────────────────────────────────
  // Android emulator: 10.0.2.2  |  Real device: 192.168.0.102  |  Production: your server
  static const String serverUrl = 'http://192.168.0.102:5000';

  void connect() {
    if (_socket != null && isConnected) return;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      isConnected = true;
      debugPrint('[WS] Connected to Node.js server');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      isConnected = false;
      debugPrint('[WS] Disconnected');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint('[WS] Connection error: $err');
      isConnected = false;
      notifyListeners();
    });

    // ── Call Signaling ─────────────────────────────────────────────────────────
    _socket!.on('incoming_call', (data) {
      debugPrint('[WS] Incoming call from ${data['callerId']}');
      onIncomingCall?.call(
        data['callId'] ?? '',
        data['callerId'] ?? '',
        data['callerName'] ?? 'Unknown',
        data['callerLang'] ?? 'en',
      );
    });

    _socket!.on('call_ringing', (data) {
      onCallRinging?.call(data['callId'] ?? '');
    });

    _socket!.on('call_accepted', (data) {
      currentCallId = data['callId'];
      onCallAccepted?.call(data['callId'] ?? '');
    });

    _socket!.on('call_rejected', (data) {
      onCallRejected?.call(data['callId'] ?? '');
    });

    _socket!.on('call_failed', (data) {
      onCallFailed?.call(data['callId'] ?? '', data['reason'] ?? 'Unknown');
    });

    _socket!.on('call_started', (data) {
      onCallStarted?.call(data['callId'] ?? '');
    });

    _socket!.on('call_ended', (data) {
      currentCallId = null;
      onCallEnded?.call(
        data['callId'] ?? '',
        data['endedBy'] ?? '',
        data['duration'] ?? 0,
      );
    });

    // ── WebRTC Signaling ───────────────────────────────────────────────────────
    _socket!.on('webrtc_offer', (data) {
      onWebRtcOffer?.call(data['callId'] ?? '', data['sdp']);
    });

    _socket!.on('webrtc_answer', (data) {
      onWebRtcAnswer?.call(data['callId'] ?? '', data['sdp']);
    });

    _socket!.on('webrtc_ice', (data) {
      onWebRtcIce?.call(data['callId'] ?? '', data['candidate']);
    });

    // ── Translation Pipeline ───────────────────────────────────────────────────
    _socket!.on('translated_audio', (data) {
      onTranslatedAudio?.call(
        data['callId'] ?? '',
        data['senderId'] ?? '',
        data['originalText'] ?? '',
        data['translatedText'] ?? '',
        data['sourceLang'] ?? 'en',
        data['targetLang'] ?? 'en',
        data['audioBase64'] ?? '',
      );
    });

    _socket!.on('own_transcript', (data) {
      onOwnTranscript?.call(
        data['callId'] ?? '',
        data['originalText'] ?? '',
        data['detectedLang'] ?? 'en',
      );
    });

    _socket!.on('subtitle_update', (data) {
      onSubtitleUpdate?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('translation_error', (data) {
      onTranslationError?.call(data['error'] ?? 'Translation failed');
    });

    _socket!.on('error', (data) {
      onError?.call(data['message'] ?? 'Unknown error');
    });
  }

  // ─── User Registration ───────────────────────────────────────────────────────
  void registerUser(String userId, String name, String language) {
    currentUserId = userId;
    _socket?.emit('register_user', {
      'userId': userId,
      'name': name,
      'language': language,
    });
  }

  // ─── Call Actions ────────────────────────────────────────────────────────────
  void initiateCall({
    required String callId,
    required String callerId,
    required String receiverId,
    required String callerName,
    required String callerLang,
    required String receiverLang,
  }) {
    currentCallId = callId;
    _socket?.emit('initiate_call', {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'callerLang': callerLang,
      'receiverLang': receiverLang,
    });
  }

  void answerCall(String callId, String receiverId, bool accepted) {
    if (accepted) currentCallId = callId;
    _socket?.emit('answer_call', {
      'callId': callId,
      'receiverId': receiverId,
      'accepted': accepted,
    });
  }

  void endCall(String callId, String userId) {
    _socket?.emit('end_call', {'callId': callId, 'userId': userId});
    currentCallId = null;
  }

  // ─── WebRTC Signaling ────────────────────────────────────────────────────────
  void sendWebRtcOffer(String callId, dynamic sdp) {
    _socket?.emit('webrtc_offer', {'callId': callId, 'sdp': sdp});
  }

  void sendWebRtcAnswer(String callId, dynamic sdp) {
    _socket?.emit('webrtc_answer', {'callId': callId, 'sdp': sdp});
  }

  void sendWebRtcIce(String callId, dynamic candidate) {
    _socket?.emit('webrtc_ice', {'callId': callId, 'candidate': candidate});
  }

  // ─── Audio Translation ───────────────────────────────────────────────────────
  void sendAudioChunk(Uint8List audioBytes, String sourceLang, String targetLang) {
    if (currentCallId == null || currentUserId == null) return;
    final b64 = base64Encode(audioBytes);
    _socket?.emit('audio_chunk', {
      'callId': currentCallId,
      'userId': currentUserId,
      'audioBase64': b64,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    });
  }

  void sendTextMessage(String text, String sourceLang, String targetLang) {
    if (currentCallId == null || currentUserId == null) return;
    _socket?.emit('text_message', {
      'callId': currentCallId,
      'userId': currentUserId,
      'text': text,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    currentCallId = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
