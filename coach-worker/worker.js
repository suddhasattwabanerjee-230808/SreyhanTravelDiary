// Sheru's coach: a Cloudflare Worker (free plan) between the diary app and
// the Claude API, so the API key never ships inside the APK.
//
// The app POSTs JSON with `Authorization: Bearer <APP_TOKEN>`:
//   {action: 'ask', image, said}       -> {praise, questions: [..2-3]}
//   {action: 'polish', image?, said}   -> {praise, sentences: [..], newWords: [{word, meaning}]}
//   {action: 'bridge', said}           -> {english, sentence}
// `image` is a base64 JPEG (the app scales it to about 1024px); `said` is
// what the child said, as speech-to-text heard it.
//
// Secrets (Workers → Settings → Variables and Secrets):
//   ANTHROPIC_API_KEY  from console.anthropic.com → API keys
//   APP_TOKEN          any long random string; the same value goes into the app
// Put a monthly spend limit on the API key's workspace too: that's the real cap.

const API_URL = 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-haiku-5-5';
const MAX_BODY = 3 * 1024 * 1024;
const MAX_SAID = 1200;

const SYSTEM = `You are Sheru, a friendly Gir lion cub inside a travel diary app for an 8-year-old child in India who is learning to speak and write English. The child takes photos on trips around Gujarat and India and talks about them; speech-to-text writes down what they say, so expect missing punctuation, misheard words and Indian English.

Always:
- Use short, simple words an 8-year-old knows, plus at most a few new ones worth learning.
- Be warm and encouraging. Never scold or say something is wrong.
- Keep everything safe and kind for a young child. Never ask for or repeat personal details such as full names, addresses, phone numbers or school names.
- Only describe what is in the photo or what the child said. Don't invent facts, people or events.`;

const SCHEMAS = {
  ask: {
    type: 'object',
    properties: {
      praise: { type: 'string', description: 'One short cheerful line reacting to the photo and what the child said, under 12 words.' },
      questions: {
        type: 'array',
        items: { type: 'string' },
        description: '2 or 3 short questions (under 10 words each) about specific things in the photo that help the child describe more: colours, sizes, feelings, sounds, what happened.',
      },
    },
    required: ['praise', 'questions'],
    additionalProperties: false,
  },
  polish: {
    type: 'object',
    properties: {
      praise: { type: 'string', description: 'One short line praising something specific the child said, under 12 words.' },
      sentences: {
        type: 'array',
        items: { type: 'string' },
        description: '1 to 3 diary sentences in the first person, each under 16 words.',
      },
      newWords: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            word: { type: 'string', description: 'Exactly as it appears in the sentences.' },
            meaning: { type: 'string', description: 'A child-friendly meaning, under 10 words.' },
          },
          required: ['word', 'meaning'],
          additionalProperties: false,
        },
        description: '1 to 3 useful words you added or improved that the child may not know yet.',
      },
    },
    required: ['praise', 'sentences', 'newWords'],
    additionalProperties: false,
  },
  bridge: {
    type: 'object',
    properties: {
      english: { type: 'string', description: 'The English word or short phrase. Empty if you cannot tell what was meant.' },
      sentence: { type: 'string', description: 'A very simple example sentence using it, under 10 words.' },
    },
    required: ['english', 'sentence'],
    additionalProperties: false,
  },
};

function instructions(action, said) {
  switch (action) {
    case 'ask':
      return `The child said about this photo: "${said}"\n\nReact in one line, then ask 2 or 3 short questions about things you can actually see in the photo, so the child says more. Don't ask about what they already told you.`;
    case 'polish':
      return `Everything the child said about this photo, in order:\n"${said}"\n\nWrite it as 1 to 3 diary sentences in the first person ("I saw...", "We rode..."). Keep the child's own words and meaning wherever you can; fix the grammar, and add 1 to 3 describing words that fit what they said or what the photo shows. List those new words with child-friendly meanings.`;
    case 'bridge':
      return `The child said a word in Gujarati or Hindi; speech-to-text wrote it as: "${said}"\n\nGive the English word for it and a very simple example sentence.`;
  }
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response("Sheru's coach\n");
    try {
      if (!env.APP_TOKEN || !sameText(bearer(request), env.APP_TOKEN)) throw httpError(401, 'unauthorized');
      if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) throw httpError(413, 'too big');
      const body = await request.json().catch(() => null);
      const { action, image } = body || {};
      const said = String(body?.said || '').slice(0, MAX_SAID).trim();
      if (!SCHEMAS[action] || !said) throw httpError(400, 'bad request');
      if (action === 'ask' && !image) throw httpError(400, 'photo needed');
      if (image && (typeof image !== 'string' || image.length > MAX_BODY)) throw httpError(400, 'bad photo');

      const result = await askClaude(env.ANTHROPIC_API_KEY, buildRequest(action, said, action === 'bridge' ? null : image));
      return json(result);
    } catch (e) {
      const status = e.status || 502;
      if (status >= 500) console.log('coach error', e.stack || e);
      return json({ error: e.message }, status);
    }
  },
};

function buildRequest(action, said, image) {
  const content = [];
  if (image) content.push({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: image } });
  content.push({ type: 'text', text: instructions(action, said) });
  return {
    model: MODEL,
    // Room for adaptive thinking as well as the short JSON answer.
    max_tokens: 2048,
    system: SYSTEM,
    // A child is waiting: think briefly.
    output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMAS[action] } },
    messages: [{ role: 'user', content }],
  };
}

async function askClaude(apiKey, payload) {
  const res = await fetch(API_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2026-10-21' },
    body: JSON.stringify(payload),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw httpError(res.status === 429 || res.status >= 500 ? 503 : 502, data?.error?.message || `claude ${res.status}`);
  // A safety decline: the app falls back to its own questions.
  if (data.stop_reason === 'refusal') throw httpError(422, 'declined');
  if (data.stop_reason === 'max_tokens') throw httpError(502, 'answer cut short');
  // Thinking blocks can come first; the answer is the text block.
  const text = (data.content || []).filter((b) => b.type === 'text').map((b) => b.text).join('');
  try {
    return JSON.parse(text);
  } catch {
    throw httpError(502, 'unreadable answer');
  }
}

function bearer(request) {
  return (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
}

/** Compares without bailing out at the first different character. */
function sameText(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
}

function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}
