/**
 * AI Service (Node.js)
 * Generates responses using OpenRouter with a fallback chain
 */

const axios = require('axios');

const FALLBACK_MODELS = [
  'mistralai/mistral-7b-instruct:free',
  'google/gemma-2-9b-it:free',
  'meta-llama/llama-3-8b-instruct:free',
];

/**
 * Generate an AI response for a given text prompt
 */
async function generateAIResponse(prompt) {
  if (!prompt?.trim()) return 'I didn\'t catch that. Could you repeat?';

  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    console.error('[AI] Missing OPENROUTER_API_KEY');
    return 'AI services are currently unavailable.';
  }

  for (const model of FALLBACK_MODELS) {
    try {
      console.log(`[AI] Attempting response with model: ${model}`);
      const response = await axios.post(
        'https://openrouter.ai/api/v1/chat/completions',
        {
          model: model,
          messages: [
            {
              role: 'system',
              content: 'You are a helpful AI assistant in a voice translator app. Give short, concise, and natural-sounding replies (max 2 sentences).',
            },
            { role: 'user', content: prompt },
          ],
          max_tokens: 100,
          temperature: 0.7,
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

      const content = response.data?.choices?.[0]?.message?.content?.trim();
      if (content) return content;
    } catch (err) {
      console.warn(`[AI] Model ${model} failed: ${err.message}`);
      // Continue to next model in fallback chain
    }
  }

  return 'I am sorry, I am having trouble connecting to my brain right now.';
}

module.exports = { generateAIResponse };
