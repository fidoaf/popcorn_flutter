const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { fetchIntroDb } = require('../src/player/introDb');
const { renderPlayerPage } = require('../src/player/playerPage');
const { createPlayerServer } = require('../src/player/playerServer');
const { ProviderRegistry } = require('../src/player/providerRegistry');

test('IntroDB lookup maps TMDB/IMDb and episode/duration to the fixed v3 API', async () => {
  for (const id of ['1399', 'tt0944947']) {
    const params = new URLSearchParams({ type: 'tv', id, season: '2', episode: '3', duration_ms: '2700000' });
    const result = await fetchIntroDb(params, async (url, options) => {
      assert.equal(url.origin, 'https://api.theintrodb.org');
      assert.equal(url.pathname, '/v3/media');
      assert.equal(url.searchParams.get(id.startsWith('tt') ? 'imdb_id' : 'tmdb_id'), id);
      assert.equal(url.searchParams.get('season'), '2');
      assert.equal(url.searchParams.get('episode'), '3');
      assert.equal(url.searchParams.get('duration_ms'), '2700000');
      assert.ok(options.signal);
      return { ok: true, json: async () => ({ intro: [{ start_ms: null, end_ms: 23000 }] }) };
    });
    assert.equal(result.intro[0].end_ms, 23000);
  }
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

function playerHarness({ timestamps = {}, query = {}, embedUrl = null, delayed = false } = {}) {
  const media = { providerId: 'test', type: 'tv', id: '42', season: '1', episode: '2', lang: 'es', sub: '0' };
  const elements = new Map();
  const messages = [];
  const requests = [];
  let resolveTimestamps;
  function element() {
    const listeners = new Map();
    return {
      hidden: true, value: '', currentTime: 0, duration: 100, options: [], dataset: {},
      addEventListener(event, callback) {
        if (!listeners.has(event)) listeners.set(event, []);
        listeners.get(event).push(callback);
      },
      async dispatch(event) { for (const callback of listeners.get(event) || []) await callback(); },
      replaceChildren(...options) { this.options = options; this.value = options[0]?.value || ''; },
      get selectedOptions() { return this.options.filter((option) => option.value === this.value); },
      add(option) { this.options.push(option); },
      appendChild() {}, pause() {}, removeAttribute() {}, load() {},
      canPlayType() { return true; },
      async play() {}, async requestFullscreen() {},
    };
  }
  const document = {
    addEventListener() {}, querySelectorAll() { return []; },
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    },
  };
  const window = {
    location: { search: '?' + new URLSearchParams({ parentOrigin: 'https://app.example', nextSeason: '2', nextEpisode: '1', ...query }) },
    parent: { postMessage(message) { messages.push(message); } },
    addEventListener() {},
  };
  const context = vm.createContext({
    document, window, URLSearchParams, Date,
    Option: function Option(label, value) { return { textContent: label, value, dataset: {} }; },
    fetch: async (url) => {
      requests.push(url);
      if (url.startsWith('/introdb')) {
        const json = delayed ? await new Promise((resolve) => { resolveTimestamps = resolve; }) : timestamps;
        return { ok: true, json: async () => json };
      }
      return { ok: true, json: async () => [] };
    },
  });
  vm.runInContext(renderPlayerPage(media, { showForm: false, embedUrl }).match(/<script>([\s\S]*?)<\/script>/)[1], context);
  return { elements, messages, requests, context, resolve(data) { resolveTimestamps(data); } };
}

test('floating controls honor exact ranges, seek intro end and request next episode with settings', async () => {
  const harness = playerHarness({ timestamps: {
    intro: [{ start_ms: 10000, end_ms: 23000 }, { start_ms: 30000, end_ms: 40000 }],
    credits: [{ start_ms: 80000, end_ms: 90000 }, { start_ms: 95000, end_ms: null }],
  } });
  const { elements, messages, requests } = harness;
  const video = elements.get('video');
  await video.dispatch('loadedmetadata');
  await elements.get('start-playback').dispatch('click');
  assert.match(requests.find((url) => url.startsWith('/introdb')), /duration_ms=100000/);
  const intro = elements.get('skip-intro');
  const next = elements.get('next-episode');
  for (const [position, visible] of [[9.999, false], [10, true], [23, false], [30, true], [40, false]]) {
    video.currentTime = position;
    await video.dispatch('timeupdate');
    assert.equal(!intro.hidden, visible);
  }
  video.currentTime = 10;
  await video.dispatch('timeupdate');
  await intro.dispatch('click');
  assert.equal(video.currentTime, 23);
  assert.equal(intro.hidden, true);
  await video.dispatch('seeked');
  assert.equal(messages.at(-1).session.positionSeconds, 23);
  for (const [position, visible] of [[79.999, false], [80, true], [90, false], [95, true]]) {
    video.currentTime = position;
    await video.dispatch('timeupdate');
    assert.equal(!next.hidden, visible);
  }
  await next.dispatch('click');
  assert.equal(messages.at(-1).type, 'popcorn:next');
  assert.equal(messages.at(-1).media.episode, '2');
  assert.equal(messages.at(-1).session.language, 'es');
  assert.equal(messages.at(-1).session.positionSeconds, 95);
});

test('unavailable next episode, unseekable intros and embedded provider controls stay hidden', async () => {
  const harness = playerHarness({
    query: { nextSeason: '', nextEpisode: '' },
    timestamps: { intro: [{ start_ms: 0, end_ms: null }, { start_ms: 0, end_ms: 200000 }], credits: [{ start_ms: 0, end_ms: null }] },
  });
  await harness.elements.get('video').dispatch('loadedmetadata');
  await harness.elements.get('start-playback').dispatch('click');
  assert.equal(harness.elements.get('skip-intro').hidden, true);
  assert.equal(harness.elements.get('next-episode').hidden, true);
  const embedded = playerHarness({ embedUrl: 'https://example.com/embed' });
  await embedded.elements.get('video').dispatch('loadedmetadata');
  assert.equal(embedded.requests.some((url) => url.startsWith('/introdb')), false);
});

test('malformed timestamps surface an error without changing playback', async () => {
  const harness = playerHarness({ timestamps: { intro: [{ start_ms: 100, end_ms: 50 }] } });
  await harness.elements.get('video').dispatch('loadedmetadata');
  assert.match(harness.elements.get('skip-status').textContent, /Skip controls unavailable: Invalid IntroDB/);
  assert.equal(harness.elements.get('skip-intro').hidden, true);
  assert.equal(harness.elements.get('video').currentTime, 0);
});

test('old source timestamp response cannot re-enable controls after a source switch', async () => {
  const harness = playerHarness({ delayed: true });
  const pending = harness.elements.get('video').dispatch('loadedmetadata');
  vm.runInContext('start(selectedMedia)', harness.context);
  harness.resolve({ intro: [{ start_ms: 0, end_ms: 23000 }], credits: [] });
  await pending;
  await harness.elements.get('start-playback').dispatch('click');
  assert.equal(harness.elements.get('skip-intro').hidden, true);
});

test('release timestamps refresh when stream duration changes without re-fetching minor jitter', async () => {
  const harness = playerHarness();
  const video = harness.elements.get('video');
  await video.dispatch('loadedmetadata');
  video.duration = 100.5;
  await video.dispatch('durationchange');
  assert.equal(harness.requests.filter((url) => url.startsWith('/introdb')).length, 1);
  video.duration = 120;
  await video.dispatch('durationchange');
  const requests = harness.requests.filter((url) => url.startsWith('/introdb'));
  assert.equal(requests.length, 2);
  assert.match(requests[1], /duration_ms=120000/);
});
