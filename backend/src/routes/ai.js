/**
 * AI REST route
 */
const express = require('express');
const router = express.Router();
const { generateAIResponse } = require('../services/aiService');

// POST /api/ai/generate-response
router.post('/generate-response', async (req, res) => {
  try {
    const { prompt } = req.body;
    if (!prompt) return res.status(400).json({ error: 'prompt required' });
    
    const responseText = await generateAIResponse(prompt);
    res.json({ success: true, prompt, response: responseText });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
