/**
 * Text-to-Speech Service (Node.js)
 * Primary: OpenAI TTS
 * Fallback: Returns empty string (client uses device TTS)
 */

const axios = require('axios');

/**
 * Convert text to speech, return base64 MP3
 */
async function textToSpeech(text, lang = 'en') {
  if (!text?.trim()) return '';

  const provider = process.env.TTS_PROVIDER || 'openai';

  try {
    if (provider === 'openai') {
      return await openAiTTS(text, lang);
    } else if (provider === 'elevenlabs') {
      return await elevenLabsTTS(text, lang);
    }
  } catch (e) {
    console.warn('[TTS] Error:', e.message, '— client will use device TTS');
  }

  return ''; // Empty → Flutter will use flutter_tts locally
}

async function openAiTTS(text, lang) {
  const apiKey = process.env.OPENAI_API_KEY || process.env.OPENROUTER_API_KEY;
  if (!apiKey) return '';

  // Map language to appropriate voice
  const voiceMap = {
    en: 'nova',    hi: 'nova',    ta: 'nova',
    es: 'nova',    fr: 'nova',    de: 'nova',
    ja: 'nova',    zh: 'nova',    ar: 'nova',
    pt: 'nova',    ko: 'nova',    ru: 'nova',
  };
  const voice = voiceMap[lang] || 'nova';

  const response = await axios.post(
    'https://api.openai.com/v1/audio/speech',
    { model: 'tts-1', input: text, voice, response_format: 'mp3' },
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      responseType: 'arraybuffer',
      timeout: 15000,
    }
  );

  return Buffer.from(response.data).toString('base64');
}

async function elevenLabsTTS(text, lang) {
  const apiKey = process.env.ELEVENLABS_API_KEY;
  if (!apiKey) return '';

  const voiceId = 'EXAVITQu4vr4xnSDxMaL'; // default voice
  const response = await axios.post(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    { text, model_id: 'eleven_multilingual_v2' },
    {
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      responseType: 'arraybuffer',
      timeout: 20000,
    }
  );

  return Buffer.from(response.data).toString('base64');
}

module.exports = { textToSpeech };
