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
  assert.equal(calls[1].url.searchParams.get('refs'), 'server-ref');
  assert.equal(calls[0].options.headers.Referer, 'https://vidsrc.buzz/');
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
  const result = await provider.listSubtitles({ providerId: provider.id, type: 'tv', id: '1399', season: '2', episode: '3' });

  assert.deepEqual(result, [{ label: 'English', lang: 'English', ref: 'sub-ref' }]);
  assert.equal(calls[1].searchParams.get('t'), 'fresh-token');
});