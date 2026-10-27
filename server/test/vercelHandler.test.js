const http = require('node:http');
const test = require('node:test');
const assert = require('node:assert/strict');
const handler = require('../src/vercelHandler');

test('Vercel handler strips the function prefix and serves health and signed playback sessions', async (t) => {
  const previous = {
    VERCEL: process.env.VERCEL,
    API_TOKENS: process.env.API_TOKENS,
    PLAYER_STATE_SECRET: process.env.PLAYER_STATE_SECRET,
  };
  process.env.VERCEL = '1';
  process.env.API_TOKENS = 'vercel-test-token';
  process.env.PLAYER_STATE_SECRET = 'a-vercel-test-secret-with-at-least-32-bytes';

  const server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    for (const [name, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const apiUrl = (path) => {
    const url = new URL('/api', base);
    url.searchParams.set('__vercel_route', path);
    return url;
  };

  const health = await fetch(apiUrl('/health'));
  assert.equal(health.status, 200);
  assert.equal(await health.text(), 'ok');

  const sessionResponse = await fetch(apiUrl('/session'), {
    headers: { Authorization: 'Bearer vercel-test-token' },
  });
  assert.equal(sessionResponse.status, 200);
  const { session } = await sessionResponse.json();
  const playerUrl = apiUrl('/player');
  playerUrl.searchParams.set('id', '42');
  playerUrl.searchParams.set('type', 'movie');
  playerUrl.searchParams.set('session', session);
  const player = await fetch(playerUrl);
  assert.equal(player.status, 200);
  assert.match(await player.text(), /playbackSession/);
});