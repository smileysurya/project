/**
 * Whisper Speech-to-Text Service (Node.js)
 * Uses OpenAI Whisper API
 */

const axios = require('axios');
const FormData = require('form-data');

/**
 * Transcribe audio bytes using Whisper API
 * @param {Buffer} audioBuffer - Raw audio bytes (WAV/MP3/WebM)
 * @param {string} language - Hint language code (optional)
 * @returns {{ text: string, language: string }}
 */
async function transcribeAudio(audioBuffer, language = null) {
  try {
    const apiKey = process.env.OPENAI_API_KEY || process.env.OPENROUTER_API_KEY;

    if (!apiKey) {
      console.warn('[STT] No API key set, returning mock text');
      return { text: 'Hello this is a test message', language: language || 'en' };
    }

    const form = new FormData();
    form.append('file', audioBuffer, {
      filename: 'audio.wav',
      contentType: 'audio/wav',
    });
    form.append('model', 'whisper-1');
    if (language && language !== 'auto') {
      form.append('language', language);
    }
    form.append('response_format', 'json');

    const response = await axios.post(
      'https://api.openai.com/v1/audio/transcriptions',
      form,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          ...form.getHeaders(),
        },
        timeout: 30000,
      }
    );

    const text = response.data?.text || '';
    // Whisper returns detected language in verbose mode; default to hint
    const detectedLang = response.data?.language || language || 'en';

    return { text: text.trim(), language: detectedLang };
  } catch (err) {
    console.error('[STT] Whisper error:', err.response?.data || err.message);
    throw new Error(`STT failed: ${err.message}`);
  }
}

module.exports = { transcribeAudio };
