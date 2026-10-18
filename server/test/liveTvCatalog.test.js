const test = require('node:test');
const assert = require('node:assert/strict');
const { LiveTvCatalog } = require('../src/liveTvCatalog');
const { Controllers } = require('../src/controllers');

const channels = [
  { id: 'beta.us', name: 'Beta TV', country: 'US', languages: ['eng'], categories: ['entertainment'], logo: 'https://example.com/beta.png' },
  { id: 'alpha.us', name: 'Alpha TV', country: 'US', languages: ['eng'], categories: ['news'], logo: 'javascript:alert(1)' },
  { id: 'missing.us', name: 'No Stream', country: 'US' },
];

const streams = [
  { channel: 'beta.us', url: 'https://example.com/beta.m3u8', http_referrer: 'https://example.com/', user_agent: 'Test player' },
  { channel: 'alpha.us', url: 'https://example.com/alpha.m3u8' },
  { channel: 'alpha.us', url: 'https://example.com/duplicate.m3u8' },
  { channel: 'missing.us', url: 'file:///private/stream.m3u8' },
  { channel: 'unknown.us', url: 'https://example.com/unknown.m3u8' },
];

const logos = [
  { channel: 'beta.us', feed: null, in_use: true, format: 'PNG', url: 'https://example.com/beta.png' },
  { channel: 'alpha.us', feed: null, url: 'javascript:alert(1)' },
];

function response(payload, status = 200) {
  return { ok: status === 200, status, json: async () => payload };
}

test('normalizes, filters, sorts, and caches the public channel catalogue', async () => {
  let calls = 0;
  let now = 100;
  const catalog = new LiveTvCatalog({
    now: () => now,
    ttlMs: 1000,
    fetchImpl: async (url) => {
      calls += 1;
      return response(url.includes('channels.json') ? channels : url.includes('streams.json') ? streams : logos);
    },
  });

  const first = await catalog.getChannels();
  assert.deepEqual(first.map((channel) => channel.name), ['Alpha TV', 'Beta TV']);
  assert.equal(first[0].logo, null);
  assert.equal(first[1].logo, 'https://example.com/beta.png');
  assert.equal(first[1].url, 'https://example.com/beta.m3u8');
  assert.deepEqual(first[1].headers, { Referer: 'https://example.com/', 'User-Agent': 'Test player' });
  assert.equal(first[1].logoFormat, 'PNG');
  assert.equal(calls, 7);

  await catalog.getChannels();
  assert.equal(calls, 7);

  now += 1001;
  await catalog.getChannels();
  assert.equal(calls, 14);
});

test('uses the GB flag for UK metadata while preserving the UK country filter', async () => {
  const catalog = new LiveTvCatalog({
    fetchImpl: async (url) => response(url.endsWith('/channels.json')
      ? [{ id: 'BBCOne.uk', name: 'BBC One', country: 'UK' }]
      : url.endsWith('/streams.json')
        ? [{ channel: 'BBCOne.uk', url: 'https://example.com/bbc.m3u8' }]
        : []),
  });
  const result = await catalog.getCatalogue({ country: 'UK' });
  assert.equal(result.channels.length, 1);
  assert.equal(result.channels[0].country, 'UK');
  assert.deepEqual(result.countries, [{
    code: 'UK',
    name: 'United Kingdom',
    names: { en: 'United Kingdom', es: 'Reino Unido', ca: 'Regne Unit' },
    flag: '\u{1F1EC}\u{1F1E7}',
  }]);
});

test('shares concurrent catalogue loads and reports upstream errors', async () => {
  let calls = 0;
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const catalog = new LiveTvCatalog({
    fetchImpl: async () => {
      calls += 1;
      await gate;
      return response([], 503);
    },
  });

  const first = catalog.getChannels();
  const second = catalog.getChannels();
  assert.equal(calls, 7);
  release();
  await assert.rejects(first, /iptv-org catalogue request failed/);
  await assert.rejects(second, /iptv-org catalogue request failed/);
});

test('resolves broadcast areas only for the selected feed without inferring access restrictions', async () => {
  const data = {
    channels: [
      { id: 'Example.fr', name: 'Example TV', country: 'FR' },
      { id: 'Missing.fr', name: 'Missing feed', country: 'FR' },
      { id: 'NoFeed.fr', name: 'No feed', country: 'FR' },
    ],
    streams: [
      { channel: 'Example.fr', feed: 'Paris', url: 'https://example.com/live.m3u8' },
      { channel: 'Missing.fr', feed: 'Missing', url: 'https://example.com/missing.m3u8' },
      { channel: 'NoFeed.fr', url: 'https://example.com/no-feed.m3u8' },
    ],
    feeds: [
      { channel: 'Example.fr', id: 'Other', broadcast_area: ['c/US'] },
      { channel: 'Example.fr', id: 'Paris', broadcast_area: ['c/FR', 'r/EUR', 's/FR-IDF', 'ct/FRPAR', 'r/UNKNOWN', 'c/FR', null, 'invalid'] },
      { channel: 'Missing.fr', id: 'Main', is_main: true, broadcast_area: ['c/US'] },
      { channel: 'NoFeed.fr', id: 'Main', is_main: true, broadcast_area: ['c/US'] },
    ],
    regions: [{ code: 'EUR', name: 'Europe' }],
    subdivisions: [{ code: 'FR-IDF', name: 'Île-de-France' }],
    cities: [{ code: 'FRPAR', name: 'Paris' }],
    logos: [],
  };
  const catalog = new LiveTvCatalog({
    fetchImpl: async (url) => response(data[url.split('/').pop().replace('.json', '')]),
  });
  const channel = await catalog.getChannel('Example.fr');
  assert.deepEqual(channel.broadcastAreas, [
    { code: 'c/FR', name: 'France', names: { en: 'France', es: 'Francia', ca: 'França' } },
    { code: 'r/EUR', name: 'Europe', names: {} },
    { code: 's/FR-IDF', name: 'Île-de-France', names: {} },
    { code: 'ct/FRPAR', name: 'Paris', names: {} },
    { code: 'r/UNKNOWN', name: 'r/UNKNOWN', names: {} },
  ]);
  assert.equal(channel.isGeoBlocked, false);
  assert.deepEqual((await catalog.getChannel('Missing.fr')).broadcastAreas, []);
  assert.deepEqual((await catalog.getChannel('NoFeed.fr')).broadcastAreas, []);
  assert.deepEqual((await catalog.getCatalogue({ channelId: 'Example.fr' })).channels[0].broadcastAreas, channel.broadcastAreas);
});

test('reports broadcast metadata failures without caching an incomplete catalogue', async () => {
  for (const source of ['feeds', 'regions', 'subdivisions', 'cities']) {
    for (const failure of [response([], 503), response({ invalid: true })]) {
      const catalog = new LiveTvCatalog({
        fetchImpl: async (url) => url.endsWith(`/${source}.json`) ? failure : response([]),
      });
      await assert.rejects(catalog.getChannels(), /catalogue request failed|invalid catalogue format/);
      assert.equal(catalog.channels, null);
    }
  }
});

test('reports geoblocking only from the selected stream labels', async () => {
  for (const [labels, expected] of [
    [['Geo-blocked', 'Not 24/7'], true],
    [[], false],
    [undefined, false],
    [null, false],
    ['Geo-blocked', false],
    [['Not 24/7'], false],
  ]) {
    const catalog = new LiveTvCatalog({
      fetchImpl: async (url) => response(url.endsWith('/channels.json')
        ? [{ id: 'Example.us', name: 'Example TV', country: 'US' }]
        : url.endsWith('/streams.json')
          ? [
            { channel: 'Example.us', url: 'https://example.com/selected.m3u8', labels },
            { channel: 'Example.us', url: 'https://example.com/other.m3u8', labels: ['Geo-blocked'] },
          ]
          : []),
    });
    const { channels } = await catalog.getCatalogue();
    assert.equal(channels[0].isGeoBlocked, expected);
    assert.equal(channels[0].url, 'https://example.com/selected.m3u8');
    assert.equal((await catalog.getChannel('Example.us')).isGeoBlocked, expected);
  }
});

test('matches logo URLs by channel and feed, preferring current horizontal white variants', async () => {
  const catalog = new LiveTvCatalog({
    fetchImpl: async (url) => response(url.endsWith('/channels.json')
      ? [{ id: 'France3.fr', name: 'France 3' }, { id: 'Generic.fr', name: 'Generic' }, { id: 'NoMatch.fr', name: 'No match' }]
      : url.endsWith('/streams.json')
        ? [
          { channel: 'France3.fr', feed: 'ParisIledeFrance', url: 'https://example.com/france.m3u8' },
          { channel: 'Generic.fr', feed: 'Main', url: 'https://example.com/generic.m3u8' },
          { channel: 'NoMatch.fr', feed: 'Main', url: 'https://example.com/other.m3u8' },
        ]
        : [
          { channel: 'France3.fr', feed: null, in_use: true, url: 'https://example.com/general.png' },
          { channel: 'France3.fr', feed: 'OtherRegion', in_use: true, url: 'https://example.com/wrong.png' },
          { channel: 'France3.fr', feed: 'ParisIledeFrance', in_use: false, tags: ['horizontal', 'white'], url: 'https://example.com/old.svg' },
          { channel: 'France3.fr', feed: 'ParisIledeFrance', in_use: true, tags: [], url: 'https://example.com/plain.png' },
          { channel: 'France3.fr', feed: 'ParisIledeFrance', in_use: true, tags: ['horizontal'], url: 'https://example.com/dark.png' },
          { channel: 'France3.fr', feed: 'ParisIledeFrance', in_use: true, tags: ['horizontal', 'white'], width: 1000, height: 468, format: 'SVG', url: 'https://example.com/logo.svg' },
          { channel: 'France3.fr', feed: 'ParisIledeFrance', in_use: true, tags: ['horizontal', 'white'], url: 'file:///private/logo.svg' },
          { channel: 'Generic.fr', feed: null, in_use: true, format: 'PNG', url: 'https://example.com/fallback.png' },
          { channel: 'NoMatch.fr', feed: 'Unrelated', in_use: true, url: 'https://example.com/unrelated.png' },
        ]),
  });
  const result = await catalog.getChannels();
  assert.equal(result[0].logo, 'https://example.com/logo.svg');
  assert.equal(result[0].logoFormat, 'SVG');
  assert.equal(result[1].logo, 'https://example.com/fallback.png');
  assert.equal(result[2].logo, null);
});

test('reports logo upstream and format failures instead of caching an incomplete catalogue', async () => {
  for (const logoResponse of [response([], 503), response({ logos: [] })]) {
    const catalog = new LiveTvCatalog({
      fetchImpl: async (url) => url.endsWith('/logos.json') ? logoResponse : response([]),
    });
    await assert.rejects(catalog.getChannels(), /catalogue request failed|invalid catalogue format/);
    assert.equal(catalog.channels, null);
  }
});

test('serves the cached catalogue with CORS headers and handles preflight requests', async () => {
  let calls = 0;
  const controller = new Controllers({
    liveTvCatalog: {
      getCatalogue: async () => {
        calls += 1;
        return { channels: [{ id: 'channel.us', name: 'Example TV' }], countries: [] };
      },
    },
  });
  const makeResponse = () => ({
    writeHead(status, headers) {
      this.status = status;
      this.headers = headers;
    },
    end(body) {
      this.body = body;
    },
  });

  const response = makeResponse();
  await controller.liveTv({ method: 'GET' }, response);
  assert.equal(response.status, 200);
  assert.equal(response.headers['Access-Control-Allow-Origin'], '*');
  assert.equal(response.headers['Cache-Control'], 'public, max-age=3600');
  assert.deepEqual(JSON.parse(response.body), { channels: [{ id: 'channel.us', name: 'Example TV' }], countries: [] });
  assert.equal(calls, 1);

  const preflight = makeResponse();
  await controller.liveTv({ method: 'OPTIONS' }, preflight);
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers['Access-Control-Allow-Methods'], 'GET, OPTIONS');
  assert.equal(calls, 1);
});

test('country filtering uses the full cache before applying the row limit', async () => {
  let calls = 0;
  const entries = [
    ...Array.from({ length: 61 }, (_, index) => ({ id: `A${index}.us`, name: `A Channel ${index}`, country: 'US' })),
    { id: 'Z.fr', name: 'Z French TV', country: 'FR' },
    { id: 'NoStream.es', name: 'No stream', country: 'ES' },
  ];
  const catalog = new LiveTvCatalog({
    fetchImpl: async (url) => {
      calls += 1;
      return response(url.endsWith('/channels.json') ? entries
        : url.endsWith('/streams.json') ? entries.slice(0, -1).map((entry) => ({ channel: entry.id, url: `https://example.com/${entry.id}.m3u8` }))
          : []);
    },
  });
  const all = await catalog.getCatalogue();
  assert.equal(all.channels.length, 60);
  assert.equal(all.channels.some((entry) => entry.country === 'FR'), false);
  assert.deepEqual(all.countries, [
    { code: 'FR', name: 'France', names: { en: 'France', es: 'Francia', ca: 'França' }, flag: '\u{1F1EB}\u{1F1F7}' },
    { code: 'US', name: 'United States', names: { en: 'United States', es: 'Estados Unidos', ca: 'Estats Units' }, flag: '\u{1F1FA}\u{1F1F8}' },
  ]);
  const filtered = await catalog.getCatalogue({ country: 'FR' });
  assert.deepEqual(filtered.channels.map((entry) => entry.id), ['Z.fr']);
  assert.deepEqual(filtered.countries, all.countries);
  assert.equal((await catalog.getCatalogue({ country: 'ES' })).channels.length, 0);
  assert.equal((await catalog.getChannel('Z.fr')).id, 'Z.fr');
  assert.equal((await catalog.getCatalogue({ channelId: 'Z.fr' })).channels[0].id, 'Z.fr');
  assert.equal((await catalog.getCatalogue()).channels.length, 60);
  assert.equal(calls, 7);
  assert.deepEqual((await catalog.getCatalogue({ query: '  FRENCH  ' })).channels.map((entry) => entry.id), ['Z.fr']);
  assert.deepEqual((await catalog.getCatalogue({ query: 'z.FR' })).channels.map((entry) => entry.id), ['Z.fr']);
  assert.equal((await catalog.getCatalogue({ country: 'US', query: 'French' })).channels.length, 0);
  assert.equal((await catalog.getCatalogue({ query: 'no such channel' })).channels.length, 0);
});
