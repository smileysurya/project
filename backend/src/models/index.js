/**
 * Mongoose Models for AI Voice Translator
 */
const mongoose = require('mongoose');

// ─── Call Log Schema ──────────────────────────────────────────────────────────
const callLogSchema = new mongoose.Schema({
  callId:       { type: String, required: true, unique: true, index: true },
  callerId:     { type: String, required: true },
  receiverId:   { type: String, required: true },
  callerName:   { type: String, default: '' },
  receiverName: { type: String, default: '' },
  callerLang:   { type: String, default: 'en' },
  receiverLang: { type: String, default: 'en' },
  status:       { type: String, enum: ['ringing', 'active', 'ended', 'missed', 'rejected'], default: 'ringing' },
  startTime:    { type: Date },
  endTime:      { type: Date },
  duration:     { type: Number, default: 0 }, // seconds
  timestamp:    { type: Date, default: Date.now },
});

// ─── Message / Transcript Schema ──────────────────────────────────────────────
const messageSchema = new mongoose.Schema({
  callId:         { type: String, required: true, index: true },
  speaker:        { type: String, required: true },   // userId
  speakerName:    { type: String, default: '' },
  originalText:   { type: String, required: true },
  translatedText: { type: String, default: '' },
  sourceLang:     { type: String, default: 'en' },
  targetLang:     { type: String, default: 'en' },
  audioBase64:    { type: String, default: '' },      // TTS audio (optional)
  timestamp:      { type: Date, default: Date.now },
  type:           { type: String, enum: ['audio', 'text'], default: 'audio' },
});

// ─── User Schema ──────────────────────────────────────────────────────────────
const userSchema = new mongoose.Schema({
  userId:       { type: String, required: true, unique: true, index: true },
  name:         { type: String, required: true },
  email:        { type: String, default: '' },
  phone:        { type: String, default: '' },
  language:     { type: String, default: 'en' },
  fcmToken:     { type: String, default: '' }, // for push notifications
  isOnline:     { type: Boolean, default: false },
  socketId:     { type: String, default: '' },
  createdAt:    { type: Date, default: Date.now },
  updatedAt:    { type: Date, default: Date.now },
});

const CallLog = mongoose.model('CallLog', callLogSchema);
const Message = mongoose.model('Message', messageSchema);
const User    = mongoose.model('User', userSchema);

module.exports = { CallLog, Message, User };
