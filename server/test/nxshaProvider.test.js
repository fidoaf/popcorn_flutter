const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { createPlayerServer } = require('../src/player/playerServer');
const { NxshaProvider, buildServersPayload, decodeData, encodeData } = require('../src/player/nxshaProvider');
const { ResourceProxy } = require('../src/player/resourceProxy');

test('builds Nxsha request payloads with matching media identifiers and defaults', () => {
  assert.deepEqual(buildServersPayload({ type: 'movie', id: '969681', season: '0', episode: '0' }), {
    tmdbId: 969681,
    imdb_id: '',
    type: 'movie',
    season: 1,
    episode: 1,
  });
  assert.deepEqual(buildServersPayload({ type: 'tv', id: 'tt22084616', season: '2', episode: '3' }), {
    tmdbId: '',
    imdb_id: 'tt22084616',
    type: 'tv',
    season: 2,
    episode: 3,
  });
  assert.deepEqual(buildServersPayload({ type: 'movie', id: '969681', imdbId: 'tt22084616' }), {
    tmdbId: 969681,
    imdb_id: 'tt22084616',
    type: 'movie',
    season: 1,
    episode: 1,
  });
});

test('resolves IMDb IDs from the Nxsha embed page before requesting its server catalog', async () => {
  const requests = [];
  let catalogPayload;
  let sourcePayload;
  const provider = new NxshaProvider({
    fetchImpl: async (input) => {
      const url = new URL(input);
      requests.push(url);
      if (url.pathname === '/embed/movie/tt22084616') {
        return new Response(String.raw`page-props:{"tmdbId":969681,"imdb_id":"$undefined"}`);
      }
      if (url.pathname === '/api/servers') {
        catalogPayload = decodeData(url.searchParams.get('q'));
        return Response.json({ _hash: encodeData({ servers: [{ scraper: 'nitro' }] }) });
      }
      if (url.pathname === '/api/sources') {
        sourcePayload = decodeData(url.searchParams.get('q'));
        return Response.json({ _hash: encodeData({ sources: [{ url: 'https://stream.example/master.m3u8', type: 'm3u8' }] }) });
      }
      throw new Error(`Unexpected request: ${url.pathname}`);
    },
  });

  const result = await provider.listSources({
    id: 'tt22084616',
    type: 'movie',
    season: '0',
    episode: '0',
    lang: 'en',
  });
  assert.equal(requests[0].pathname, '/embed/movie/tt22084616');
  assert.equal(requests[1].pathname, '/api/servers');
  assert.equal(requests[2].pathname, '/api/sources');
  assert.equal(catalogPayload.tmdbId, 969681);
  assert.equal(catalogPayload.imdb_id, 'tt22084616');
  assert.equal(sourcePayload.tmdbId, 969681);
  assert.equal(sourcePayload.imdb_id, 'tt22084616');
  assert.equal(sourcePayload.provider, 'nitro');
  assert.equal(result.sources.length, 1);
  assert.equal(result.sources[0].ref.url, 'https://stream.example/master.m3u8');
});

test('serves decoded Nxsha servers after generating the encrypted q parameter server-side', async (t) => {
  let requestUrl;
  let requestOptions;
  const expectedServers = [{ id: 'vid-example', name: 'Example server', scraper: 'example' }];
  const provider = new NxshaProvider({
    fetchImpl: async (input, options) => {
      requestUrl = new URL(input);
      requestOptions = options;
      return Response.json({ _hash: encodeData({ servers: expectedServers }) });
    },
  });
  const providers = new ProviderRegistry([provider], 'nxsha');
  const server = createPlayerServer({ providers, resourceProxy: {} });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const response = await fetch(`http://127.0.0.1:${server.address().port}/nxsha/servers?type=movie&id=969681`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), expectedServers);
  assert.equal(requestUrl.origin, 'https://web.nxsha.app');
  assert.equal(requestUrl.pathname, '/api/servers');
  const payload = decodeData(requestUrl.searchParams.get('q'));
  assert.deepEqual({
    tmdbId: payload.tmdbId,
    imdb_id: payload.imdb_id,
    type: payload.type,
    season: payload.season,
    episode: payload.episode,
  }, {
    tmdbId: 969681,
    imdb_id: '',
    type: 'movie',
    season: 1,
    episode: 1,
  });
  assert.equal(requestOptions.headers.Referer, 'https://web.nxsha.app/');
});

test('returns null when an Nxsha encrypted value cannot be decoded', () => {
  assert.equal(decodeData('not-encrypted'), null);
});

test('falls back to browser transport when Node fetch fails', async () => {
  let browserFetchCalls = 0;
  const logs = [];
  const logger = Object.fromEntries(['debug', 'info', 'warn', 'error'].map((level) => [
    level,
    (message, meta) => logs.push({ level, message, meta }),
  ]));
  const provider = new NxshaProvider({
    fetchImpl: async () => { throw new TypeError('fetch failed'); },
    logger,
    browserFetchImpl: async (input) => {
      browserFetchCalls += 1;
      assert.equal(new URL(input).pathname, '/api/servers');
      return Response.json({ _hash: encodeData({ servers: [{ scraper: 'nitro' }] }) });
    },
  });

  assert.deepEqual(await provider.listServers({ id: '969681', type: 'movie' }), [{ scraper: 'nitro' }]);
  assert.equal(browserFetchCalls, 1);
  assert.equal(logs.some((entry) => entry.message === 'Node API request failed; trying Chromium'), true);
  assert.equal(logs.some((entry) => entry.message === 'API request completed' && entry.meta.transport === 'chromium'), true);
  assert.equal(JSON.stringify(logs).includes('U2FsdGVk'), false);
});

test('decodes the supplied Nxsha q value', () => {
  const decoded = decodeData('U2FsdGVkX18aoDPHk9dZwZNy4KOFL5-kijOziEAXE7QFs-ejFgDweENZ2VVg8wHVp4rZnfDkVLmDPK2E-vSztiAvKOA_R632b73qmwDC1Xsyn5ePnwYsmnH2GyPV7ZkWDSHaPEnoe0JBgXeS9DTh5cSUAOsgb_RrtK0NH9QY4EywPVZ8hEq6bpbcdhC6mLBw');

  assert.deepEqual(decoded, {
    tmdbId: 969681,
    imdb_id: '',
    type: 'movie',
    season: 1,
    episode: 1,
  });
});

test('resolves Nxsha scraper sources to a proxied HLS manifest in the local player', async (t) => {
  const upstreamCalls = [];
  const sourcePayloads = [];
  const servers = [
    { name: 'App-only', scraper: 'app-only', web_support: false },
    { name: 'ShowNitro', scraper: 'showbox-online', web_support: true },
    { name: 'Embed provider', scraper: 'embed-only', web_support: true },
    { name: 'Nitro provider', scraper: 'nitro', web_support: true },
  ];
  const hlsUrl = 'https://wts.itsnitrox.tech/nitro/example-token/master.m3u8';
  const fetchImpl = async (input) => {
    const url = new URL(input);
    upstreamCalls.push(url);
    if (url.pathname === '/api/servers') {
      return Response.json({ _hash: encodeData({ servers }) });
    }
    if (url.pathname === '/api/sources') {
      const payload = decodeData(url.searchParams.get('q'));
      sourcePayloads.push(payload);
      if (payload.provider === 'embed-only') {
        return Response.json({ _hash: encodeData({ sources: [{ url: 'https://embed.example/player', type: 'embed', isEmbed: true }] }) });
      }
      if (payload.provider === 'nitro') {
        return Response.json({ _hash: encodeData({ sources: [{ url: hlsUrl, type: 'hls', quality: '1080p', language: 'English' }] }) });
      }
    }
    if (url.href === hlsUrl) {
      return new Response('#EXTM3U\n#EXT-X-ENDLIST', {
        headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
      });
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };
  const provider = new NxshaProvider({ fetchImpl });
  const providers = new ProviderRegistry([provider], 'nxsha');
  const resourceProxy = new ResourceProxy({ providers, fetchImpl });
  const server = createPlayerServer({ providers, resourceProxy });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const player = await fetch(`${base}/player?provider=nxsha&type=movie&id=969681`, { redirect: 'manual' });
  assert.equal(player.status, 200);
  assert.match(await player.text(), /const initialMedia = \{"providerId":"nxsha"/);

  const automaticManifest = await fetch(`${base}/manifest?provider=nxsha&type=movie&id=969681`);
  assert.equal(automaticManifest.status, 200);
  assert.match(await automaticManifest.text(), /^#EXTM3U/);

  const sourceList = await (await fetch(`${base}/sources?provider=nxsha&type=movie&id=969681`)).json();
  assert.equal(sourceList.length, 1);
  assert.match(sourceList[0].label, /Nitro provider/);
  assert.equal(sourceList[0].language, 'English');

  const manifest = await fetch(`${base}/manifest?provider=nxsha&type=movie&id=969681&source=${sourceList[0].id}`);
  assert.equal(manifest.status, 200);
  assert.match(await manifest.text(), /^#EXTM3U/);
  assert.equal(sourcePayloads.some((payload) => payload.provider === 'nitro'
    && payload.tmdbId === 969681 && payload.ex_lang === true), true);
  assert.equal(sourcePayloads.some((payload) => payload.provider === 'app-only'
    || payload.provider === 'showbox-online'), false);
  assert.equal(upstreamCalls.some((url) => url.pathname === '/api/sources' && decodeData(url.searchParams.get('q')).provider === 'showbox-online'), false);
  assert.equal(upstreamCalls.some((url) => url.hostname === 'wts.itsnitrox.tech'), true);
});

test('lists Nxsha subtitles and serves the selected OpenSubtitles file as WebVTT', async (t) => {
  const subtitleUrl = 'https://dl.opensubtitles.org/en/download/src-api/vrf-test/file/1962635948';
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    if (url.pathname === '/api/subtitles') {
      const payload = decodeData(url.searchParams.get('q'));
      assert.deepEqual({ tmdbId: payload.tmdbId, type: payload.type, season: payload.season, episode: payload.episode }, {
        tmdbId: 969681,
        type: 'movie',
        season: 1,
        episode: 1,
      });
      return Response.json({ _hash: encodeData({ subtitles: [{
        title: 'English',
        language: 'en',
        type: 'application/x-subrip',
        contentType: 'movie',
        uri: subtitleUrl,
      }] }) });
    }
    if (url.href === subtitleUrl) {
      assert.equal(options.headers.Referer, 'https://web.nxsha.app/');
      return new Response('1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n', {
        headers: { 'Content-Type': 'application/x-subrip' },
      });
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };
  const provider = new NxshaProvider({ fetchImpl });
  const providers = new ProviderRegistry([provider], 'nxsha');
  const server = createPlayerServer({ providers, resourceProxy: {} });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const tracks = await (await fetch(`${base}/subtitles?provider=nxsha&type=movie&id=969681`)).json();
  assert.equal(tracks.length, 1);
  assert.equal(tracks[0].label, 'English');
  assert.equal(tracks[0].language, 'en');
  const response = await fetch(`${base}/subtitle/${tracks[0].id}`);
  assert.equal(response.headers.get('content-type'), 'text/vtt; charset=utf-8');
  assert.equal(await response.text(), 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n');
});

test('rejects OpenSubtitles HTML error pages instead of serving them as subtitle tracks', async () => {
  const provider = new NxshaProvider({
    fetchImpl: async () => new Response('<html>Download temporarily unavailable</html>', {
      headers: { 'Content-Type': 'text/html; charset=UTF-8' },
    }),
  });

  await assert.rejects(
    provider.fetchSubtitle('https://dl.opensubtitles.org/en/download/src-api/vrf-test/file/123'),
    /HTML error page/,
  );
});