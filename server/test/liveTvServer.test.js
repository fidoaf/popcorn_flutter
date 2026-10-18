const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../server');
const { ProviderRegistry } = require('../src/player/providerRegistry');

async function startServer(t, fetchImpl, apiTokens = new Set(['test-server-token'])) {
  const server = createServer(null, {
    providers: new ProviderRegistry([{ id: 'test', label: 'Test' }]),
    resourceProxy: {},
    apiTokens,
    fetchImpl,
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}/live-tv`;
}

test('active server authenticates Live TV, handles CORS, and serves a cached catalogue', async (t) => {
  const upstreamCalls = [];
  const url = await startServer(t, async (input) => {
    upstreamCalls.push(input);
    return new Response(JSON.stringify(input.endsWith('/channels.json')
      ? [{ id: 'Example.us', name: 'Example TV', country: 'US' }]
      : input.endsWith('/streams.json')
        ? [{ channel: 'Example.us', url: 'https://example.com/live.m3u8' }]
        : [{ channel: 'Example.us', feed: null, in_use: true, format: 'SVG', url: 'https://example.com/logo.svg' }]));
  });
  for (const headers of [{}, { Authorization: 'Bearer invalid-token' }]) {
    const response = await fetch(url, { headers });
    assert.equal(response.status, 401);
    assert.equal(response.headers.get('www-authenticate'), 'Bearer');
  }
  assert.equal(upstreamCalls.length, 0);
  const preflight = await fetch(url, { method: 'OPTIONS', headers: {
    Origin: 'https://app.example',
    'Access-Control-Request-Method': 'GET',
    'Access-Control-Request-Headers': 'authorization',
  } });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get('access-control-allow-headers'), /Authorization/);
  for (let i = 0; i < 2; i += 1) {
    const response = await fetch(url, { headers: { Authorization: 'Bearer test-server-token' } });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('access-control-allow-origin'), '*');
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const { channels, countries } = await response.json();
    assert.deepEqual(countries, [{
      code: 'US', name: 'United States', names: { en: 'United States', es: 'Estados Unidos', ca: 'Estats Units' }, flag: '\u{1F1FA}\u{1F1F8}',
    }]);
    assert.equal(channels.length, 1);
    assert.equal(channels[0].name, 'Example TV');
    assert.equal(channels[0].url, 'https://example.com/live.m3u8');
    assert.equal(channels[0].logo, 'https://example.com/logo.svg');
    assert.equal(channels[0].logoFormat, 'SVG');
  }
  assert.equal(upstreamCalls.length, 3);
});

test('active server reports catalogue failures as JSON and allows retry', async (t) => {
  let failed = true;
  const url = await startServer(t, async () => failed
    ? new Response('Unavailable', { status: 503 })
    : new Response('[]'), new Set());
  const unavailable = await fetch(url);
  assert.equal(unavailable.status, 502);
  assert.deepEqual(await unavailable.json(), { error: 'live_tv_unavailable' });
  failed = false;
  const retry = await fetch(url);
  assert.equal(retry.status, 200);
  assert.deepEqual(await retry.json(), { channels: [], countries: [] });
});

test('active server filters countries and looks up channels independently of the row filter', async (t) => {
  const url = await startServer(t, async (input) => new Response(JSON.stringify(
    input.endsWith('/channels.json')
      ? [{ id: 'US.us', name: 'American TV', country: 'US' }, { id: 'FR.fr', name: 'French TV', country: 'FR' }]
      : input.endsWith('/streams.json')
        ? [{ channel: 'US.us', url: 'https://example.com/us.m3u8' }, { channel: 'FR.fr', url: 'https://example.com/fr.m3u8' }]
        : [],
  )));
  const headers = { Authorization: 'Bearer test-server-token' };
  const filtered = await fetch(`${url}?country=FR`, { headers });
  assert.equal(filtered.status, 200);
  const data = await filtered.json();
  assert.deepEqual(data.channels.map((entry) => entry.id), ['FR.fr']);
  assert.equal(data.countries.length, 2);
  const lookup = await fetch(`${url}?channel=US.us&country=FR`, { headers });
  assert.deepEqual((await lookup.json()).channels.map((entry) => entry.id), ['US.us']);
  const cleared = await fetch(url, { headers });
  assert.equal((await cleared.json()).channels.length, 2);
  const searched = await fetch(`${url}?q=fReNcH`, { headers });
  assert.deepEqual((await searched.json()).channels.map((entry) => entry.id), ['FR.fr']);
});
