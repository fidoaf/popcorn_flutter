const test = require('node:test');
const assert = require('node:assert/strict');
const { VidSrcBuzzProvider } = require('../src/player/vidsrcBuzzProvider');

test('extracts and validates an HLS candidate using the provider API', async () => {
  const calls = [];
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    calls.push({ url, options });
    if (url.pathname === '/embed/movie/tt1375666') {
      return new Response('var Q = {"type":"movie","id":"tt1375666","s":0,"e":0,"t":"token","ssr":{"servers":[{"ref":"server-ref"}]}};');
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'race') {
      return Response.json({ cands: [{ url: '/stream/master.m3u8', type: 'hls' }] });
    }
    if (url.pathname === '/stream/master.m3u8') {
      return new Response('#EXTM3U\n#EXT-X-ENDLIST', { headers: { 'Content-Type': 'application/vnd.apple.mpegurl' } });
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const result = await provider.extract({ providerId: provider.id, type: 'movie', id: 'tt1375666', season: '0', episode: '0' });

  assert.equal(result.url, 'https://vidsrc.buzz/stream/master.m3u8');
  assert.equal(result.type, 'hls');
  assert.deepEqual(calls.map(({ url }) => url.pathname), [
    '/embed/movie/tt1375666',
    '/pl/api.php',
    '/stream/master.m3u8',
  ]);
  assert.equal(calls[0].url.searchParams.get('lang'), 'en');
  assert.equal(calls[0].url.searchParams.get('sub'), '1');
  assert.equal(calls[1].url.searchParams.get('refs'), 'server-ref');
  assert.equal(calls[0].options.headers.Referer, 'https://vidsrc.buzz/');
});

test('falls back to per-server play when the race endpoint fails', async () => {
  const fetchImpl = async (input) => {
    const url = new URL(input);
    if (url.pathname === '/embed/tv/97645/5/2') {
      return new Response('var Q = {"type":"tv","id":"97645","s":5,"e":2,"t":"token","ssr":{"servers":[{"ref":"server-ref"}]}};');
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'race') {
      return new Response('', { status: 502, statusText: 'Bad Gateway' });
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'play') {
      return Response.json({ url: '/stream/master.m3u8', type: 'hls' });
    }
    if (url.pathname === '/stream/master.m3u8') {
      return new Response('#EXTM3U\n#EXT-X-ENDLIST');
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const result = await provider.extract({ providerId: provider.id, type: 'tv', id: '97645', season: '5', episode: '2' });

  assert.equal(result.url, 'https://vidsrc.buzz/stream/master.m3u8');
});

test('lists VidSrc.buzz servers and extracts the selected source', async () => {
  const calls = [];
  const fetchImpl = async (input) => {
    const url = new URL(input);
    calls.push(url);
    if (url.pathname === '/embed/movie/tt1375666') {
      return new Response('var Q = {"type":"movie","id":"tt1375666","s":0,"e":0,"t":"page-token","ssr":{"servers":[{"ref":"first-ref","name":"Server SWM1","lang":"English","flag":"us"},{"ref":"second-ref","name":"Server VEM-3"}]}};');
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'play') {
      return Response.json({ url: '/stream/selected.m3u8', type: 'hls' });
    }
    if (url.pathname === '/stream/selected.m3u8') {
      return new Response('#EXTM3U\n#EXT-X-ENDLIST');
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const media = { providerId: provider.id, type: 'movie', id: 'tt1375666', season: '0', episode: '0' };
  const result = await provider.listSources(media);

  assert.equal(result.token, 'page-token');
  assert.deepEqual(result.sources, [
    { ref: 'first-ref', name: 'Server SWM1', lang: 'English', flag: 'us' },
    { ref: 'second-ref', name: 'Server VEM-3', lang: '', flag: '' },
  ]);

  const stream = await provider.extract(media, { ref: 'second-ref', token: result.token });
  assert.equal(stream.url, 'https://vidsrc.buzz/stream/selected.m3u8');
  const playRequest = calls.find((url) => url.pathname === '/pl/api.php');
  assert.equal(playRequest.searchParams.get('a'), 'play');
  assert.equal(playRequest.searchParams.get('ref'), 'second-ref');
  assert.equal(playRequest.searchParams.get('t'), 'page-token');
});

test('skips candidates whose playlist segments are unavailable', async () => {
  const fetchImpl = async (input) => {
    const url = new URL(input);
    if (url.pathname === '/embed/tv/97645/1/1') {
      return new Response('var Q = {"type":"tv","id":"97645","s":1,"e":1,"t":"token","ssr":{"servers":[{"ref":"dead"},{"ref":"live"}]}};');
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'race') {
      return Response.json({ cands: [{ url: '/dead/master.m3u8', type: 'hls' }, { url: '/live/master.m3u8', type: 'hls' }] });
    }
    if (url.pathname.endsWith('/master.m3u8')) {
      return new Response('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nvariant.m3u8\n');
    }
    if (url.pathname.endsWith('/variant.m3u8')) {
      return new Response('#EXTM3U\n#EXTINF:2.000,\nseg0.ts\n#EXT-X-ENDLIST');
    }
    if (url.pathname === '/dead/seg0.ts') return new Response('{"code":3403}', { status: 403 });
    if (url.pathname === '/live/seg0.ts') return new Response('segment');
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const result = await provider.extract({ providerId: provider.id, type: 'tv', id: '97645', season: '1', episode: '1' });

  assert.equal(result.url, 'https://vidsrc.buzz/live/master.m3u8');
});

test('falls back to last-resort servers when the initial servers are unplayable', async () => {
  const calls = [];
  const fetchImpl = async (input) => {
    const url = new URL(input);
    calls.push(url);
    const action = url.searchParams.get('a');
    if (url.pathname === '/embed/tv/97645/1/1') {
      return new Response('var Q = {"type":"tv","id":"tt8910922","s":1,"e":1,"t":"token","ssr":{"more":true,"servers":[{"ref":"xpk","k":"xpk-key","name":"Server XPK"}]}};');
    }
    if (action === 'race') return Response.json({ cands: [{ url: '/xpk/index.m3u8', type: 'hls' }] });
    if (action === 'sources' && url.searchParams.get('pf') === '1') {
      return Response.json({ status: 'ok', servers: [{ ref: 'xpk-resigned', k: 'xpk-key', name: 'Server XPK' }, { ref: 'vnh', k: 'vnh-key', name: 'Server VNH' }] });
    }
    if (action === 'play') return Response.json({ url: `/${url.searchParams.get('ref')}/index.m3u8`, type: 'hls' });
    if (url.pathname.endsWith('/index.m3u8')) return new Response('#EXTM3U\n#EXTINF:2.000,\nseg0.ts\n#EXT-X-ENDLIST');
    if (url.pathname === '/xpk/seg0.ts') return new Response('{"code":3403}', { status: 403 });
    if (url.pathname === '/vnh/seg0.ts') return new Response('segment');
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const media = { providerId: provider.id, type: 'tv', id: '97645', season: '1', episode: '1' };
  const result = await provider.extract(media);

  assert.equal(result.url, 'https://vidsrc.buzz/vnh/index.m3u8');
  assert.deepEqual(
    calls.filter((url) => url.searchParams.get('a') === 'play').map((url) => url.searchParams.get('ref')),
    ['xpk', 'vnh'],
  );

  const { sources } = await provider.listSources(media);
  assert.deepEqual(sources.map(({ ref }) => ref), ['xpk', 'vnh']);
});

test('lists subtitles with a fresh page token', async () => {
  const calls = [];
  const fetchImpl = async (input) => {
    const url = new URL(input);
    calls.push(url);
    if (url.pathname === '/embed/tv/1399/2/3') {
      return new Response('var Q = {"type":"tv","id":"1399","s":2,"e":3,"t":"fresh-token"};');
    }
    if (url.pathname === '/pl/api.php' && url.searchParams.get('a') === 'subs') {
      return Response.json({ subs: [{ label: 'English', lang: 'English', ref: 'sub-ref' }] });
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new VidSrcBuzzProvider({ fetchImpl });
  const result = await provider.listSubtitles({ providerId: provider.id, type: 'tv', id: '1399', season: '2', episode: '3', lang: 'fr', sub: '0' });

  assert.deepEqual(result, [{ label: 'English', lang: 'English', ref: 'sub-ref' }]);
  assert.equal(calls[0].searchParams.get('lang'), 'fr');
  assert.equal(calls[0].searchParams.get('sub'), '0');
  assert.equal(calls[1].searchParams.get('t'), 'fresh-token');
});