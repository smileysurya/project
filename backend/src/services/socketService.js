/**
 * Socket.IO Service - 1-to-1 Call System
 *
 * Replaces room-based (walkie-talkie) model with:
 *  - Direct caller → receiver signaling
 *  - WebRTC offer/answer/ICE exchange
 *  - Real-time audio translation pipeline
 *  - Live subtitle broadcast
 */

const { transcribeAudio } = require('./whisperService');
const { translateText }   = require('./translationService');
const { textToSpeech }    = require('./ttsService');
const { CallLog, Message, User } = require('../models');

// Map: userId → socketId  (for direct messaging)
const onlineUsers = new Map();

// Map: callId → { callerId, receiverId, callerLang, receiverLang, startTime }
const activeCalls = new Map();

function registerSocketHandlers(io) {
  io.on('connection', (socket) => {
    console.log(`[WS] Client connected: ${socket.id}`);

    // ─── User Registration ────────────────────────────────────────────────────
    socket.on('register_user', async ({ userId, name, language }) => {
      if (!userId) return;

      onlineUsers.set(userId, socket.id);
      socket.userId = userId;
      socket.userLang = language || 'en';
      socket.userName = name || userId;

      // Update DB
      try {
        await User.findOneAndUpdate(
          { userId },
          { isOnline: true, socketId: socket.id, language: language || 'en', name: name || userId, updatedAt: new Date() },
          { upsert: true, new: true }
        );
      } catch (e) { /* ignore */ }

      socket.emit('registered', { userId, socketId: socket.id });
      console.log(`[WS] User registered: ${userId} (${name})`);
    });

    // ─── Initiate Call ────────────────────────────────────────────────────────
    /**
     * Caller emits: initiate_call
     * data: { callId, callerId, receiverId, callerName, callerLang, receiverLang }
     */
    socket.on('initiate_call', async (data) => {
      const { callId, callerId, receiverId, callerName, callerLang, receiverLang } = data;
      const receiverSocketId = onlineUsers.get(receiverId);

      // Store call state
      activeCalls.set(callId, {
        callerId,
        receiverId,
        callerLang: callerLang || 'en',
        receiverLang: receiverLang || 'en',
        callerSocketId: socket.id,
        receiverSocketId,
        startTime: null,
      });

      // Save to DB as ringing
      try {
        await CallLog.create({
          callId,
          callerId,
          receiverId,
          callerName: callerName || callerId,
          callerLang: callerLang || 'en',
          receiverLang: receiverLang || 'en',
          status: 'ringing',
          timestamp: new Date(),
        });
      } catch (e) { console.error('[DB] Call create error:', e.message); }

      if (receiverSocketId) {
        // Notify receiver
        io.to(receiverSocketId).emit('incoming_call', {
          callId,
          callerId,
          callerName: callerName || callerId,
          callerLang,
          receiverLang,
        });
        socket.emit('call_ringing', { callId, receiverId });
        console.log(`[CALL] ${callerId} → ${receiverId} (callId: ${callId})`);
      } else {
        // Receiver offline → missed call
        socket.emit('call_failed', { callId, reason: 'User is offline' });
        await CallLog.findOneAndUpdate({ callId }, { status: 'missed' });
        console.log(`[CALL] Receiver offline: ${receiverId}`);
      }
    });

    // ─── Call Answer ──────────────────────────────────────────────────────────
    socket.on('answer_call', async ({ callId, receiverId, accepted }) => {
      const call = activeCalls.get(callId);
      if (!call) return;

      if (accepted) {
        const startTime = new Date();
        call.startTime = startTime;
        call.receiverSocketId = socket.id;
        activeCalls.set(callId, call);

        await CallLog.findOneAndUpdate({ callId }, { status: 'active', startTime });

        io.to(call.callerSocketId).emit('call_accepted', { callId, receiverId });
        socket.emit('call_started', { callId });
        console.log(`[CALL] Call accepted: ${callId}`);
      } else {
        activeCalls.delete(callId);
        await CallLog.findOneAndUpdate({ callId }, { status: 'rejected' });
        io.to(call.callerSocketId).emit('call_rejected', { callId, receiverId });
        console.log(`[CALL] Call rejected: ${callId}`);
      }
    });

    // ─── WebRTC Signaling ─────────────────────────────────────────────────────
    /**
     * Relay WebRTC offer from caller to receiver
     */
    socket.on('webrtc_offer', ({ callId, sdp }) => {
      const call = activeCalls.get(callId);
      if (!call) return;
      const targetId = socket.userId === call.callerId
        ? call.receiverSocketId
        : call.callerSocketId;
      if (targetId) io.to(targetId).emit('webrtc_offer', { callId, sdp });
    });

    socket.on('webrtc_answer', ({ callId, sdp }) => {
      const call = activeCalls.get(callId);
      if (!call) return;
      const targetId = socket.userId === call.receiverId
        ? call.callerSocketId
        : call.receiverSocketId;
      if (targetId) io.to(targetId).emit('webrtc_answer', { callId, sdp });
    });

    socket.on('webrtc_ice', ({ callId, candidate }) => {
      const call = activeCalls.get(callId);
      if (!call) return;
      const targetId = socket.userId === call.callerId
        ? call.receiverSocketId
        : call.callerSocketId;
      if (targetId) io.to(targetId).emit('webrtc_ice', { callId, candidate });
    });

    // ─── Audio Translation Pipeline ───────────────────────────────────────────
    /**
     * Client sends audio chunk for translation:
     * data: { callId, userId, audioBase64, sourceLang, targetLang }
     *
     * Pipeline:
     *  Audio bytes → Whisper STT → Translate → TTS → emit to both peers
     */
    socket.on('audio_chunk', async (data) => {
      const { callId, userId, audioBase64, sourceLang, targetLang } = data;

      if (!audioBase64 || !callId) return;

      const call = activeCalls.get(callId);
      if (!call) return;

      try {
        const audioBytes = Buffer.from(audioBase64, 'base64');

        // Step 1: Whisper STT
        const sttResult = await transcribeAudio(audioBytes, sourceLang);
        const originalText = sttResult.text || '';
        const detectedLang = sttResult.language || sourceLang;

        if (!originalText.trim()) return;

        console.log(`[STT][${detectedLang}] "${originalText}"`);

        // Step 2: Translate
        const translatedText = await translateText(originalText, detectedLang, targetLang);
        console.log(`[TRL][${targetLang}] "${translatedText}"`);

        // Step 3: TTS (translated audio for receiver)
        const audioResponseB64 = await textToSpeech(translatedText, targetLang);

        // Step 4: Save transcript to DB
        await Message.create({
          callId,
          speaker: userId,
          speakerName: socket.userName || userId,
          originalText,
          translatedText,
          sourceLang: detectedLang,
          targetLang,
          timestamp: new Date(),
          type: 'audio',
        });

        // Step 5: Send own transcript back to speaker
        socket.emit('own_transcript', {
          callId,
          originalText,
          detectedLang,
        });

        // Step 6: Send translated subtitle + audio to the OTHER peer
        const targetSocketId = userId === call.callerId
          ? call.receiverSocketId
          : call.callerSocketId;

        if (targetSocketId) {
          io.to(targetSocketId).emit('translated_audio', {
            callId,
            senderId: userId,
            originalText,
            translatedText,
            sourceLang: detectedLang,
            targetLang,
            audioBase64: audioResponseB64,
          });
        }

        // Also broadcast subtitles to both parties
        const subtitlePayload = {
          callId,
          senderId: userId,
          speakerName: socket.userName || userId,
          originalText,
          translatedText,
          sourceLang: detectedLang,
          targetLang,
          timestamp: new Date().toISOString(),
        };

        socket.emit('subtitle_update', subtitlePayload);
        if (targetSocketId) io.to(targetSocketId).emit('subtitle_update', subtitlePayload);

      } catch (err) {
        console.error('[WS] Audio processing error:', err.message);
        socket.emit('translation_error', { callId, error: err.message });
      }
    });

    // ─── Text Message (in-call) ───────────────────────────────────────────────
    socket.on('text_message', async (data) => {
      const { callId, userId, text, sourceLang, targetLang } = data;
      if (!text?.trim() || !callId) return;

      const call = activeCalls.get(callId);
      if (!call) return;

      try {
        const translatedText = await translateText(text, sourceLang, targetLang);
        const audioB64 = await textToSpeech(translatedText, targetLang);

        await Message.create({
          callId,
          speaker: userId,
          speakerName: socket.userName || userId,
          originalText: text,
          translatedText,
          sourceLang,
          targetLang,
          timestamp: new Date(),
          type: 'text',
        });

        const payload = {
          callId, senderId: userId,
          originalText: text, translatedText,
          sourceLang, targetLang, audioBase64: audioB64,
          timestamp: new Date().toISOString(),
        };

        socket.emit('own_transcript', { callId, originalText: text, detectedLang: sourceLang });

        const targetSocketId = userId === call.callerId
          ? call.receiverSocketId
          : call.callerSocketId;
        if (targetSocketId) io.to(targetSocketId).emit('translated_audio', payload);

      } catch (err) {
        socket.emit('translation_error', { error: err.message });
      }
    });

    // ─── End Call ─────────────────────────────────────────────────────────────
    socket.on('end_call', async ({ callId, userId }) => {
      const call = activeCalls.get(callId);
      if (!call) return;

      const duration = call.startTime
        ? Math.floor((Date.now() - call.startTime.getTime()) / 1000)
        : 0;

      activeCalls.delete(callId);

      await CallLog.findOneAndUpdate(
        { callId },
        { status: 'ended', endTime: new Date(), duration }
      ).catch(() => {});

      // Notify both parties
      const otherSocketId = userId === call.callerId
        ? call.receiverSocketId
        : call.callerSocketId;

      const endPayload = { callId, endedBy: userId, duration };
      socket.emit('call_ended', endPayload);
      if (otherSocketId) io.to(otherSocketId).emit('call_ended', endPayload);

      console.log(`[CALL] Ended: ${callId} (${duration}s)`);
    });

    // ─── Disconnect ───────────────────────────────────────────────────────────
    socket.on('disconnect', async () => {
      const userId = socket.userId;
      if (!userId) return;

      onlineUsers.delete(userId);

      try {
        await User.findOneAndUpdate({ userId }, { isOnline: false, socketId: '' });
      } catch (e) { /* ignore */ }

      // End any active call this user was in
      for (const [callId, call] of activeCalls.entries()) {
        if (call.callerId === userId || call.receiverId === userId) {
          const otherSocketId = userId === call.callerId
            ? call.receiverSocketId
            : call.callerSocketId;

          if (otherSocketId) {
            io.to(otherSocketId).emit('call_ended', { callId, endedBy: userId, reason: 'disconnected' });
          }

          const duration = call.startTime
            ? Math.floor((Date.now() - call.startTime.getTime()) / 1000)
            : 0;

          await CallLog.findOneAndUpdate({ callId }, { status: 'ended', endTime: new Date(), duration }).catch(() => {});
          activeCalls.delete(callId);
        }
      }

      console.log(`[WS] Disconnected: ${userId}`);
    });
  });
}

module.exports = { registerSocketHandlers, onlineUsers, activeCalls };
