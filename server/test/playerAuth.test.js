const http = require('node:http');
const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../server');
const { PlayerAuth } = require('../src/player/playerAuth');
const { parseTokens } = require('../src/config');
const { ProviderRegistry } = require('../src/player/providerRegistry');

test('bearer authorization gates APIs and playback resources, with public health and preflight', async (t) => {
  const upstream = http.createServer((request, response) => {
    assert.equal(request.headers.authorization, undefined);
    assert.equal(new URL(request.url, 'http://localhost').searchParams.has('session'), false);
    if (request.url === '/master.m3u8') {
      response.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      response.end('#EXTM3U\nvariant.m3u8\n');
    } else if (request.url === '/variant.m3u8') {
      response.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      response.end('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:4,\nchunk.ts\n');
    } else {
      assert.equal(request.headers.range, 'bytes=0-3');
      response.writeHead(206, { 'Content-Type': 'application/octet-stream', 'Content-Range': 'bytes 0-3/4' });
      response.end('data');
    }
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => upstream.close(resolve)));
  const origin = `http://127.0.0.1:${upstream.address().port}`;
  const providers = new ProviderRegistry([{
    id: 'test', label: 'Test', origin,
    extract: async () => ({ url: `${origin}/master.m3u8` }),
    listSubtitles: async () => [{ ref: 'subtitle-ref', label: 'English', lang: 'en' }],
    fetchSubtitle: async () => new Response('WEBVTT\n', { headers: { 'Content-Type': 'text/vtt' } }),
  }]);
  const server = createServer(null, { providers, apiTokens: parseTokens('first-token, second-token') });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  for (const path of ['/', '/player?id=42&type=movie', '/providers', '/manifest', '/sources', '/subtitles', '/introdb', '/watch-providers', '/resource/unknown', '/subtitle/unknown', '/session']) {
    const response = await fetch(base + path);
    assert.equal(response.status, 401, path);
    assert.equal(response.headers.get('www-authenticate'), 'Bearer');
  }
  assert.equal((await fetch(`${base}/health`)).status, 200);
  for (const path of ['/session', '/watch-providers', '/providers']) {
    const preflight = await fetch(base + path, { method: 'OPTIONS', headers: {
      Origin: 'https://app.example',
      'Access-Control-Request-Method': 'GET',
      'Access-Control-Request-Headers': 'authorization',
    } });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-headers'), 'Authorization, Range');
  }
  for (const token of ['first-token', 'second-token']) {
    assert.equal((await fetch(`${base}/providers`, { headers: { Authorization: `Bearer ${token}` } })).status, 200);
  }
  assert.equal((await fetch(`${base}/providers?token=first-token`)).status, 401);
  assert.equal((await fetch(`${base}/session`, { headers: { Authorization: 'Bearer invalid' } })).status, 401);
  const sessionResponse = await fetch(`${base}/session`, { headers: { Authorization: 'Bearer first-token' } });
  assert.equal(sessionResponse.headers.get('cache-control'), 'no-store');
  const { session } = await sessionResponse.json();
  assert.match(session, /^[a-f0-9]{64}$/);
  assert.equal((await fetch(`${base}/session?session=${session}`)).status, 401);
  const bearerPage = await fetch(`${base}/player?id=42&type=movie&session=invalid`, {
    headers: { Authorization: 'Bearer second-token' },
  });
  assert.equal(bearerPage.status, 200);
  assert.doesNotMatch(await bearerPage.text(), /const playbackSession = "invalid"/);
  const mediaQuery = `id=42&type=movie&session=${session}`;
  const player = await fetch(`${base}/player?${mediaQuery}`);
  const html = await player.text();
  assert.equal(player.status, 200);
  assert.equal(player.headers.get('referrer-policy'), 'no-referrer');
  assert.ok(html.includes(session));
  assert.ok(!html.includes('first-token'));
  const master = await (await fetch(`${base}/manifest?${mediaQuery}`)).text();
  const variantPath = master.split('\n').find((line) => line.startsWith('/resource/'));
  assert.equal(new URL(variantPath, base).searchParams.get('session'), session);
  const variant = await (await fetch(base + variantPath)).text();
  const segmentPath = variant.split('\n').find((line) => line.startsWith('/resource/'));
  const keyPath = variant.match(/URI="([^"]+)"/)[1];
  for (const path of [segmentPath, keyPath]) {
    assert.equal(new URL(path, base).searchParams.get('session'), session);
    const response = await fetch(base + path, { headers: { Range: 'bytes=0-3' } });
    assert.equal(response.status, 206);
    assert.equal(await response.text(), 'data');
    assert.equal((await fetch(base + path.split('?')[0])).status, 401);
  }
  const subtitles = await (await fetch(`${base}/subtitles?${mediaQuery}`)).json();
  assert.equal(await (await fetch(`${base}/subtitle/${subtitles[0].id}?session=${session}`)).text(), 'WEBVTT\n');
});

test('playback sessions expire after inactivity, renew while used, and cannot mint sessions', () => {
  let now = 1000;
  const auth = new PlayerAuth(new Set(['token']), { now: () => now, sessionTtlMs: 100 });
  const request = { headers: {} };
  const session = auth.createSession();
  const url = new URL(`http://localhost/player?session=${session}`);
  now += 99;
  assert.equal(auth.authorize(request, url), true);
  now += 99;
  assert.equal(auth.authorize(request, url), true);
  assert.equal(auth.authorize(request, new URL(`http://localhost/session?session=${session}`)), false);
  now += 100;
  assert.equal(auth.authorize(request, url), false);
  assert.equal(auth.sessions.size, 0);
});

test('empty token configuration preserves unauthenticated development behavior', () => {
  const auth = new PlayerAuth(parseTokens(''));
  assert.equal(auth.authorize({ headers: {} }, new URL('http://localhost/providers')), true);
  assert.equal(auth.pageSession(new URL('http://localhost/player')), null);
});
