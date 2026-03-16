/**
 * Translation Service (Node.js)
 * Primary: LibreTranslate
 * Fallback: OpenRouter (GPT-based translation)
 */

const axios = require('axios');

/**
 * Translate text from sourceLang to targetLang
 */
async function translateText(text, sourceLang, targetLang) {
  if (!text?.trim()) return '';
  if (sourceLang === targetLang) return text;

  // Try LibreTranslate first
  try {
    const result = await translateLibre(text, sourceLang, targetLang);
    if (result) return result;
  } catch (e) {
    console.warn('[TRL] LibreTranslate failed, trying OpenRouter fallback');
  }

  // Fallback: OpenRouter (LLM-based translation)
  return translateOpenRouter(text, sourceLang, targetLang);
}

async function translateLibre(text, sourceLang, targetLang) {
  const url = process.env.LIBRETRANSLATE_URL || 'https://libretranslate.com';
  const apiKey = process.env.LIBRETRANSLATE_API_KEY || '';

  const body = {
    q: text,
    source: sourceLang === 'auto' ? 'auto' : sourceLang,
    target: targetLang,
    format: 'text',
  };
  if (apiKey) body.api_key = apiKey;

  const response = await axios.post(`${url}/translate`, body, {
    headers: { 'Content-Type': 'application/json' },
    timeout: 10000,
  });

  return response.data?.translatedText || null;
}

async function translateOpenRouter(text, sourceLang, targetLang) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    console.warn('[TRL] No OpenRouter key, returning original text');
    return text;
  }

  const langNames = {
    en: 'English', ta: 'Tamil', hi: 'Hindi', es: 'Spanish',
    fr: 'French', de: 'German', ja: 'Japanese', zh: 'Chinese',
    ar: 'Arabic', pt: 'Portuguese', ko: 'Korean', ru: 'Russian',
    it: 'Italian', nl: 'Dutch', tr: 'Turkish',
  };

  const srcName = langNames[sourceLang] || sourceLang;
  const tgtName = langNames[targetLang] || targetLang;

  const response = await axios.post(
    'https://openrouter.ai/api/v1/chat/completions',
    {
      model: 'openai/gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: `You are a precise translator. Translate the given text from ${srcName} to ${tgtName}. Return ONLY the translated text, no explanations or quotation marks.`,
        },
        { role: 'user', content: text },
      ],
      max_tokens: 500,
      temperature: 0.2,
    },
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://ai-voice-translator.app',
      },
      timeout: 15000,
    }
  );

  return response.data?.choices?.[0]?.message?.content?.trim() || text;
}

module.exports = { translateText };
