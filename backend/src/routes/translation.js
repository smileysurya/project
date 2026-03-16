/**
 * Translation REST route
 */
const express = require('express');
const router = express.Router();
const { translateText } = require('../services/translationService');

// POST /api/translation/translate
router.post('/translate', async (req, res) => {
  try {
    const { text, sourceLang, targetLang } = req.body;
    if (!text) return res.status(400).json({ error: 'text required' });
    const translated = await translateText(text, sourceLang || 'en', targetLang || 'en');
    res.json({ success: true, originalText: text, translatedText: translated, sourceLang, targetLang });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
