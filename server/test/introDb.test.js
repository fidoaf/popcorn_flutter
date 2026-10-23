const test = require('node:test');
const assert = require('node:assert/strict');
const { fetchIntroDb } = require('../src/player/introDb');
const { createPlayerServer } = require('../src/player/playerServer');
const { ProviderRegistry } = require('../src/player/providerRegistry');

test('IntroDB lookup maps TMDB/IMDb and episode/duration to the fixed v4 API', async () => {
  for (const id of ['1399', 'tt0944947']) {
    const params = new URLSearchParams({ type: 'tv', id, season: '2', episode: '3', duration_ms: '2700000' });
    const result = await fetchIntroDb(params, async (url, options) => {
      assert.equal(url.origin, 'https://api.theintrodb.org');
      assert.equal(url.pathname, '/v4/media');
      assert.equal(url.searchParams.get(id.startsWith('tt') ? 'imdb_id' : 'tmdb_id'), id);
      assert.equal(url.searchParams.get('season'), '2');
      assert.equal(url.searchParams.get('episode'), '3');
      assert.equal(url.searchParams.get('duration_ms'), '2700000');
      assert.equal(url.searchParams.has('type'), false);
      assert.equal(url.searchParams.has('mapping'), false);
      assert.ok(options.signal);
      return { ok: true, json: async () => ({ tvdb_id: 121361, type: 'tv', season: 2, episode: 3, intro: [{ start_ms: null, end_ms: 23000 }] }) };
    });
    assert.equal(result.intro[0].end_ms, 23000);
    assert.equal(result.tvdb_id, 121361);
    assert.equal(Object.hasOwn(result, 'tmdb_id'), false);
  }
});

test('IntroDB v4 movie requests omit TV parameters and preserve omitted segment arrays', async () => {
  const result = await fetchIntroDb(new URLSearchParams({ type: 'movie', id: '42', duration_ms: '60000' }), async (url) => {
    assert.equal(url.pathname, '/v4/media');
    assert.deepEqual(Object.fromEntries(url.searchParams), { tmdb_id: '42', duration_ms: '60000' });
    return { ok: true, json: async () => ({ tvdb_id: 123, type: 'movie' }) };
  });
  assert.deepEqual(result, { tvdb_id: 123, type: 'movie' });
});

test('IntroDB distinguishes missing data from upstream failures and rejects bad input', async () => {
  const params = new URLSearchParams({ type: 'movie', id: '42', duration_ms: '60000' });
  assert.deepEqual(await fetchIntroDb(params, async () => ({ status: 404 })), { intro: [], credits: [] });
  await assert.rejects(fetchIntroDb(params, async () => ({ ok: false, status: 503 })), /503/);
  for (const input of [
    { type: 'movie', id: '42', duration_ms: 'NaN' },
    { type: 'tv', id: '42', duration_ms: '60000', season: '1', episode: '0' },
    { type: 'movie', id: 'https://example.com', duration_ms: '60000' },
  ]) {
    await assert.rejects(fetchIntroDb(new URLSearchParams(input), () => assert.fail('Must not fetch')), { statusCode: 400 });
  }
});

test('hosted server serves the IntroDB proxy without provider extraction', async (t) => {
  const server = createPlayerServer({
    providers: new ProviderRegistry([{ id: 'test', label: 'Test' }], 'test'),
    resourceProxy: {},
    fetchImpl: async () => ({ ok: true, json: async () => ({ intro: [], credits: [] }) }),
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/introdb?type=movie&id=42&duration_ms=60000`;
  const response = await fetch(url);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { intro: [], credits: [] });
});
