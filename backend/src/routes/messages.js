/**
 * Messages REST route
 */
const express = require('express');
const router = express.Router();
const { Message } = require('../models');

// GET /api/messages?callId=xxx
router.get('/', async (req, res) => {
  try {
    const { callId } = req.query;
    if (!callId) return res.status(400).json({ error: 'callId required' });
    const messages = await Message.find({ callId }).sort({ timestamp: 1 }).lean();
    res.json({ success: true, messages });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// DELETE /api/messages/:callId
router.delete('/:callId', async (req, res) => {
  try {
    await Message.deleteMany({ callId: req.params.callId });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
