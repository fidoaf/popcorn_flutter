const test = require('node:test');
const assert = require('node:assert/strict');
const { RadioCatalog } = require('../src/radioCatalog');
const { createServer } = require('../server');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { Controllers } = require('../src/controllers');

const id = '1cfb151d-a341-11e9-a787-52543be04c81';
const station = {
  stationuuid: id, name: ' France Info ', url: 'https://example.com/fallback.mp3',
  url_resolved: 'https://example.com/live.mp3', favicon: 'https://example.com/logo.png',
  homepage: 'https://example.com', country: 'France', countrycode: 'FR',
  language: 'french, english', tags: 'news, talk', codec: 'MP3', bitrate: 128, lastcheckok: 1,
};
const resolveServers = async () => [{ name: 'de1.api.radio-browser.info' }, { name: 'de2.api.radio-browser.info' }];
const response = (payload, status = 200) => new Response(JSON.stringify(payload), { status });

test('normalizes online stations, uses resolved URLs, deduplicates and caches concurrent loads', async () => {
  let calls = 0;
  let discoveries = 0;
  let now = 0;
  const catalog = new RadioCatalog({
    now: () => now,
    resolveServers: async () => { discoveries += 1; return resolveServers(); },
    fetchImpl: async (url, options) => {
      calls += 1;
      assert.match(options.headers['User-Agent'], /PopcornFlutter/);
      assert.equal(options.headers.Accept, 'application/json');
      assert.ok(options.signal);
      const query = new URL(url).searchParams;
      assert.equal(query.get('hidebroken'), 'true');
      if (url.includes('/countrycodes')) return response([{ name: 'FR', stationcount: 10 }]);
      assert.equal(query.get('order'), 'clickcount');
      assert.equal(query.get('limit'), '60');
      return response([station, station, { ...station, lastcheckok: 0 }, { ...station, stationuuid: 'invalid' },
        { ...station, stationuuid: '00000000-0000-0000-0000-000000000001', url: 'file:///private/audio', url_resolved: null }]);
    },
  });
  const [first, second] = await Promise.all([catalog.getCatalogue(), catalog.getCatalogue()]);
  assert.deepEqual(first, second);
  assert.equal(calls, 2);
  assert.equal(discoveries, 1);
  assert.deepEqual(first.stations, [{
    id, name: 'France Info', url: 'https://example.com/live.mp3', logo: 'https://example.com/logo.png',
    website: 'https://example.com/', country: 'France', countryCode: 'FR', languages: ['french', 'english'],
    tags: ['news', 'talk'], codec: 'MP3', bitrate: 128,
  }]);
  await catalog.getCatalogue();
  assert.equal(calls, 2);
  now += 60 * 60 * 1000 + 1;
  await catalog.getCatalogue();
  assert.equal(calls, 4);
  assert.equal(discoveries, 2);
});

test('retries another discovered mirror for network, status and format failures', async () => {
  for (const failure of [new Error('Network unavailable'), response({}, 503), response({ invalid: true })]) {
    const hosts = [];
    const catalog = new RadioCatalog({
      resolveServers, random: () => 0.99,
      fetchImpl: async (url) => {
        if (url.includes('/countrycodes')) return response([]);
        hosts.push(new URL(url).host);
        if (hosts.length === 1) {
          if (failure instanceof Error) throw failure;
          return failure;
        }
        return response([station]);
      },
    });
    assert.equal((await catalog.getCatalogue()).stations.length, 1);
    assert.deepEqual(hosts, ['de1.api.radio-browser.info', 'de2.api.radio-browser.info']);
  }
});

test('failed discovery or requests are explicit and retryable, not cached as empty success', async () => {
  let failed = true;
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async () => failed ? response([], 503) : response([]),
  });
  await assert.rejects(catalog.getCatalogue(), /Radio Browser is unavailable/);
  assert.equal(catalog.catalogues.size, 0);
  failed = false;
  assert.deepEqual(await catalog.getCatalogue(), { stations: [], countries: [] });
  const missing = new RadioCatalog({ resolveServers: async () => [{ name: 'invalid.example' }] });
  await assert.rejects(missing.getCatalogue(), /no servers/);
});

test('filters upstream before the station limit with independent caches and a full localized country directory', async () => {
  const calls = [];
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async (input) => {
      const url = new URL(input);
      calls.push(url);
      if (url.pathname.endsWith('/countrycodes')) return response([
        { name: 'FR', stationcount: 100 }, { name: 'ES', stationcount: 200 },
        { name: 'GB', stationcount: 300 }, { name: 'FR', stationcount: 100 },
        { name: 'BAD', stationcount: 10 }, { name: 'AD', stationcount: 0 },
      ]);
      const country = url.searchParams.get('countrycode');
      return response(country === 'ES'
        ? [{ ...station, name: 'Radio España', country: 'Spain', countrycode: 'ES' }]
        : [station]);
    },
  });
  const all = await catalog.getCatalogue();
  const [spanish, same] = await Promise.all([catalog.getCatalogue({ country: 'ES' }), catalog.getCatalogue({ country: 'ES' })]);
  assert.deepEqual(spanish, same);
  assert.equal(spanish.stations[0].name, 'Radio España');
  assert.equal(all.stations[0].name, 'France Info');
  assert.deepEqual(spanish.countries, all.countries);
  assert.deepEqual(all.countries.map((entry) => entry.code), ['FR', 'ES', 'GB']);
  assert.equal(all.countries[1].names.es, 'España');
  assert.equal(all.countries[1].names.ca, 'Espanya');
  assert.equal(all.countries[2].flag, '\u{1F1EC}\u{1F1E7}');
  assert.equal(calls.length, 3);
  assert.equal(calls[2].searchParams.get('countrycode'), 'ES');
  assert.equal(calls[2].searchParams.get('limit'), '60');
  assert.equal((await catalog.getCatalogue()).stations[0].countryCode, 'FR');
  await catalog.getCatalogue({ country: 'ES' });
  assert.equal(calls.length, 3);
  for (const country of ['Spain', '../ES', 'es', null]) {
    await assert.rejects(catalog.getCatalogue({ country }), { statusCode: 400 });
  }
  assert.equal(calls.length, 3);
});

test('searches names upstream before the result limit and caches by query and country', async () => {
  const requests = [];
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async (input) => {
      const url = new URL(input);
      requests.push(url);
      if (url.pathname.endsWith('/countrycodes')) return response([]);
      const name = url.searchParams.get('name');
      return response(name === 'missing' ? [] : [{ ...station, name: name || 'Popular station' }]);
    },
  });
  assert.equal((await catalog.getCatalogue()).stations[0].name, 'Popular station');
  const [searched, duplicate] = await Promise.all([
    catalog.getCatalogue({ query: '  Ràdio Music & News  ' }),
    catalog.getCatalogue({ query: 'ràdio music & news' }),
  ]);
  assert.deepEqual(searched, duplicate);
  assert.equal(searched.stations[0].name, 'Ràdio Music & News');
  const searchUrl = requests.find((url) => url.searchParams.has('name'));
  assert.equal(searchUrl.searchParams.get('name'), 'Ràdio Music & News');
  assert.equal(searchUrl.searchParams.get('limit'), '60');
  assert.equal(searchUrl.searchParams.has('countrycode'), false);
  await catalog.getCatalogue({ country: 'FR', query: 'Ràdio Music & News' });
  assert.equal(requests.at(-1).searchParams.get('countrycode'), 'FR');
  assert.equal(requests.at(-1).searchParams.get('name'), 'Ràdio Music & News');
  const count = requests.length;
  await catalog.getCatalogue({ query: 'RÀDIO MUSIC & NEWS' });
  await catalog.getCatalogue({ query: '   ' });
  assert.equal(requests.length, count);
  assert.deepEqual((await catalog.getCatalogue({ query: 'missing' })).stations, []);
  await assert.rejects(catalog.getCatalogue({ query: null }), { statusCode: 400 });
});

test('looks up stations outside the home list and reports a click only when playback starts', async () => {
  const paths = [];
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async (url) => {
      const path = new URL(url).pathname;
      paths.push(path);
      return response(path.startsWith('/json/url/') ? { ok: true, stationuuid: id, url: 'https://example.com/play.mp3' } : [station]);
    },
  });
  assert.equal((await catalog.getStation(id)).id, id);
  assert.deepEqual(paths, [`/json/stations/byuuid/${id}`]);
  assert.deepEqual(await catalog.startPlayback(id), { url: 'https://example.com/play.mp3' });
  assert.deepEqual(paths, [`/json/stations/byuuid/${id}`, `/json/url/${id}`]);
  for (const invalid of [null, '', '../../url', 'not-a-uuid']) {
    await assert.rejects(catalog.startPlayback(invalid), { statusCode: 400 });
    await assert.rejects(catalog.getStation(invalid), { statusCode: 400 });
  }
  assert.equal(paths.length, 2);
});

test('rejects unsafe playback URLs and handles missing stations', async () => {
  for (const url of ['file:///private/audio', 'javascript:alert(1)', 'https://user:password@example.com/audio']) {
    const catalog = new RadioCatalog({
      resolveServers,
      fetchImpl: async () => response({ ok: true, stationuuid: id, url }),
    });
    await assert.rejects(catalog.startPlayback(id), /unavailable/);
  }
  const catalog = new RadioCatalog({ resolveServers, fetchImpl: async () => response([]) });
  assert.equal(await catalog.getStation(id), null);
});

test('radio endpoints enforce bearer auth and support CORS, station lookup, playback and JSON errors', async (t) => {
  let calls = 0;
  let fail = false;
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async (url) => {
      calls += 1;
      if (fail) return response([], 503);
      if (url.includes('/countrycodes')) return response([{ name: 'FR', stationcount: 10 }, { name: 'ES', stationcount: 20 }]);
      if (new URL(url).searchParams.get('name') === 'Jazz') return response([{ ...station, name: 'Jazz Radio' }]);
      if (new URL(url).searchParams.get('countrycode') === 'ES') {
        return response([{ ...station, name: 'Spanish Radio', country: 'Spain', countrycode: 'ES' }]);
      }
      return response(url.includes('/json/url/') ? { ok: true, stationuuid: id, url: station.url_resolved } : [station]);
    },
  });
  const server = createServer(null, {
    providers: new ProviderRegistry([{ id: 'test', label: 'Test' }]),
    resourceProxy: {}, apiTokens: new Set(['radio-test']), radioCatalog: catalog,
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const path of ['/radio', `/radio/play?station=${id}`]) {
    assert.equal((await fetch(base + path)).status, 401);
    const preflight = await fetch(base + path, { method: 'OPTIONS' });
    assert.equal(preflight.status, 204);
    assert.match(preflight.headers.get('access-control-allow-headers'), /Authorization/);
  }
  assert.equal(calls, 0);
  const headers = { Authorization: 'Bearer radio-test' };
  const list = await fetch(`${base}/radio`, { headers });
  assert.equal(list.status, 200);
  assert.equal(list.headers.get('access-control-allow-origin'), '*');
  assert.equal((await list.json()).stations[0].id, id);
  const filtered = await (await fetch(`${base}/radio?country=ES`, { headers })).json();
  assert.equal(filtered.stations[0].name, 'Spanish Radio');
  assert.equal(filtered.countries.length, 2);
  const searched = await (await fetch(`${base}/radio?q=Jazz`, { headers })).json();
  assert.equal(searched.stations[0].name, 'Jazz Radio');
  const invalidCountry = await fetch(`${base}/radio?country=Spain`, { headers });
  assert.equal(invalidCountry.status, 400);
  assert.deepEqual(await invalidCountry.json(), { error: 'invalid_radio_country' });
  assert.equal((await (await fetch(`${base}/radio?station=${id}`, { headers })).json()).stations[0].id, id);
  assert.deepEqual(await (await fetch(`${base}/radio/play?station=${id}`, { headers })).json(), { url: station.url_resolved });
  const invalid = await fetch(`${base}/radio/play?station=invalid`, { headers });
  assert.equal(invalid.status, 400);
  assert.deepEqual(await invalid.json(), { error: 'invalid_radio_station' });
  fail = true;
  const unavailable = await fetch(`${base}/radio/play?station=${id}`, { headers });
  assert.equal(unavailable.status, 502);
  assert.deepEqual(await unavailable.json(), { error: 'radio_unavailable' });
});

test('legacy radio handlers support catalogue, playback, preflight and explicit failures', async () => {
  const catalog = new RadioCatalog({
    resolveServers,
    fetchImpl: async (url) => response(url.includes('/json/url/')
      ? { ok: true, stationuuid: id, url: station.url_resolved }
      : [{ ...station, name: new URL(url).searchParams.get('name') || station.name }]),
  });
  const controllers = new Controllers({ radioCatalog: catalog });
  const request = async (path, method = 'GET') => {
    const result = {
      writeHead(status, headers) { this.status = status; this.headers = headers; },
      end(body) { this.body = body ? JSON.parse(body) : null; },
    };
    await controllers.radio({ method, log: { error() {} } }, result, new URL(path, 'http://localhost'));
    return result;
  };
  assert.equal((await request('/radio')).body.stations[0].id, id);
  assert.equal((await request('/radio?q=Jazz')).body.stations[0].name, 'Jazz');
  assert.equal((await request(`/radio?station=${id}`)).body.stations[0].id, id);
  assert.deepEqual((await request(`/radio/play?station=${id}`)).body, { url: station.url_resolved });
  assert.equal((await request('/radio', 'OPTIONS')).status, 204);
  assert.equal((await request('/radio', 'POST')).status, 405);
  const invalid = await request('/radio/play?station=invalid');
  assert.equal(invalid.status, 400);
  assert.deepEqual(invalid.body, { error: 'invalid_radio_station' });
});
