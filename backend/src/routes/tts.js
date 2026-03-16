/**
 * Text-to-Speech REST route
 */
const express = require('express');
const router = express.Router();
const { textToSpeech } = require('../services/ttsService');

// POST /api/tts/synthesize
router.post('/synthesize', async (req, res) => {
  try {
    const { text, language } = req.body;
    if (!text) return res.status(400).json({ error: 'text required' });
    const audioBase64 = await textToSpeech(text, language || 'en');
    res.json({ success: true, audioBase64, language });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
