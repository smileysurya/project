/**
 * Speech-to-Text REST route
 */
const express = require('express');
const multer = require('multer');
const router = express.Router();
const { transcribeAudio } = require('../services/whisperService');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: parseInt(process.env.MAX_AUDIO_SIZE) || 10 * 1024 * 1024 },
});

// POST /api/speech/transcribe  (multipart: file=audio)
router.post('/transcribe', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No audio file' });
    const lang = req.body.language || null;
    const result = await transcribeAudio(req.file.buffer, lang);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
