import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _recorderInitialized = false;

  Future<void> init() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _recorderInitialized = true;
  }

  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _player.dispose();
  }

  // ─── Recording with VAD ───────────────────────────────────────────────────
  Future<void> startContinuousRecording({
    required Function(Uint8List chunk) onChunk,
    double thresholdDB = -40.0,
    int silenceMs = 800,
  }) async {
    if (!_recorderInitialized) await init();

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/vad_chunk.wav';

    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    
    int silenceCounter = 0;
    bool hasSpoken = false;

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    _recorder.onProgress?.listen((e) async {
      final db = e.decibels ?? -100.0;
      
      if (db > thresholdDB) {
        silenceCounter = 0;
        hasSpoken = true;
      } else {
        if (hasSpoken) {
          silenceCounter += 100;
        }
      }

      if (hasSpoken && silenceCounter >= silenceMs) {
        // VAD Trigger
        silenceCounter = 0;
        hasSpoken = false;
        
        try {
          await _recorder.stopRecorder();
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.length > 16000) { // Avoid tiny chunks
               onChunk(bytes);
            }
          }
          // Restart for next sentence
          if (_recorderInitialized) { // Check if still initialized
            await _recorder.startRecorder(
              toFile: path,
              codec: Codec.pcm16WAV,
              sampleRate: 16000,
              numChannels: 1,
            );
          }
        } catch (e) {
          debugPrint('[Audio] VAD Trigger error: $e');
        }
      }
    });
  }

  Future<void> stopRecording() async {
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
  }

  bool get isRecording => _recorder.isRecording;

  // ─── Playback ────────────────────────────────────────────────────────────────
  Future<void> playBase64Audio(String base64Audio) async {
    if (base64Audio.isEmpty) return;
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('[Audio] Playback error: $e');
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }
}
