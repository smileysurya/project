/**
 * Calls REST API Routes
 */
const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { CallLog, Message } = require('../models');

// POST /api/calls/start
router.post('/start', async (req, res) => {
  try {
    const { callerId, receiverId, callerName, receiverName, callerLang, receiverLang } = req.body;
    const callId = uuidv4();

    const call = await CallLog.create({
      callId, callerId, receiverId,
      callerName: callerName || callerId,
      receiverName: receiverName || receiverId,
      callerLang: callerLang || 'en',
      receiverLang: receiverLang || 'en',
      status: 'ringing',
      timestamp: new Date(),
    });

    res.json({ success: true, callId, call });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/calls/end
router.post('/end', async (req, res) => {
  try {
    const { callId, duration } = req.body;
    await CallLog.findOneAndUpdate(
      { callId },
      { status: 'ended', duration: duration || 0, endTime: new Date() }
    );
    res.json({ success: true, callId });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/calls/history?userId=xxx
router.get('/history', async (req, res) => {
  try {
    const { userId } = req.query;
    const query = userId
      ? { $or: [{ callerId: userId }, { receiverId: userId }] }
      : {};
    const calls = await CallLog.find(query)
      .sort({ timestamp: -1 }).limit(50).lean();
    res.json({ success: true, calls });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/calls/:callId/transcript
router.get('/:callId/transcript', async (req, res) => {
  try {
    const { callId } = req.params;
    const messages = await Message.find({ callId })
      .sort({ timestamp: 1 }).lean();
    res.json({ success: true, callId, messages });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
