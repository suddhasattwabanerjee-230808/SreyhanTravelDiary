// Tests for worker.js (node coach-worker/test.mjs), with the Claude API faked:
// token checks, the request sent to Claude, and how answers and failures come
// back to the app.
import assert from 'node:assert/strict';

const worker = (await import(new URL('./worker.js', import.meta.url))).default;
const env = { APP_TOKEN: 'test-token-123', ANTHROPIC_API_KEY: 'sk-test' };

let sent = null;
let reply = null;
globalThis.fetch = async (url, init) => {
  sent = { url, headers: init.headers, body: JSON.parse(init.body) };
  return new Response(JSON.stringify(reply.body), { status: reply.status ?? 200 });
};

function call(body, token = env.APP_TOKEN) {
  return worker.fetch(
    new Request('https://coach.example/', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }),
    env,
  );
}

const answer = (obj, extra = {}) => ({
  body: {
    stop_reason: 'end_turn',
    content: [{ type: 'thinking', thinking: '', signature: 'x' }, { type: 'text', text: JSON.stringify(obj) }],
    ...extra,
  },
});

// A GET is a friendly hello, for checking the deploy in a browser.
assert.equal(await (await worker.fetch(new Request('https://coach.example/'), env)).text(), "Sheru's coach\n");

// Wrong or missing token.
reply = answer({});
assert.equal((await call({ action: 'ask', said: 'hi', image: 'AAAA' }, 'nope')).status, 401);
assert.equal((await worker.fetch(new Request('https://coach.example/', { method: 'POST', body: '{}' }), env)).status, 401);

// Bad requests never reach Claude.
sent = null;
assert.equal((await call({ action: 'hack', said: 'hi' })).status, 400);
assert.equal((await call({ action: 'ask', said: '' , image: 'AAAA' })).status, 400);
assert.equal((await call({ action: 'ask', said: 'a camel' })).status, 400);
assert.equal(sent, null);

// ask: photo + words in, questions out.
reply = answer({ praise: 'Wow, a camel!', questions: ['What colour was it?', 'Was it tall?'] });
let res = await call({ action: 'ask', said: 'we saw a camel', image: 'AAAA' });
assert.equal(res.status, 200);
assert.deepEqual(await res.json(), { praise: 'Wow, a camel!', questions: ['What colour was it?', 'Was it tall?'] });
assert.equal(sent.url, 'https://api.anthropic.com/v1/messages');
assert.equal(sent.headers['x-api-key'], 'sk-test');
assert.equal(sent.body.model, 'claude-haiku-5-5');
assert.equal(sent.body.output_config.format.type, 'json_schema');
assert.deepEqual(sent.body.output_config.format.schema.required, ['praise', 'questions']);
assert.equal(sent.body.messages[0].content[0].type, 'image');
assert.equal(sent.body.messages[0].content[0].source.data, 'AAAA');
assert.match(sent.body.messages[0].content[1].text, /we saw a camel/);
assert.equal(sent.body.temperature, undefined);

// polish works without a photo too; bridge never sends one.
reply = answer({ praise: 'Great!', sentences: ['I rode a tall camel.'], newWords: [{ word: 'tall', meaning: 'very high' }] });
res = await call({ action: 'polish', said: 'camel ride it was tall' });
assert.equal((await res.json()).sentences[0], 'I rode a tall camel.');
assert.equal(sent.body.messages[0].content.length, 1);
reply = answer({ english: 'camel', sentence: 'A camel has a hump.' });
res = await call({ action: 'bridge', said: 'oont', image: 'AAAA' });
assert.equal((await res.json()).english, 'camel');
assert.equal(sent.body.messages[0].content.some((b) => b.type === 'image'), false);

// Very long speech is trimmed before it's sent.
await call({ action: 'bridge', said: 'a'.repeat(5000) });
assert.ok(sent.body.messages[0].content[0].text.length < 1500);

// Failures the app turns into its offline questions.
reply = answer({}, { stop_reason: 'refusal', content: [] });
assert.equal((await call({ action: 'ask', said: 'hi', image: 'AAAA' })).status, 422);
reply = { status: 529, body: { error: { message: 'overloaded' } } };
assert.equal((await call({ action: 'ask', said: 'hi', image: 'AAAA' })).status, 503);
reply = { body: { stop_reason: 'end_turn', content: [{ type: 'text', text: 'not json' }] } };
assert.equal((await call({ action: 'ask', said: 'hi', image: 'AAAA' })).status, 502);

console.log('coach worker: all tests passed');
