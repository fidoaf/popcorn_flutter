const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { createServer } = require('../server');

function masterPlaylist(firstPath, secondPath) {
  return `#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=5692000,RESOLUTION=1920x1080,NAME="1080p"\n${firstPath}\n#EXT-X-STREAM-INF:BANDWIDTH=2628000,RESOLUTION=1280x720,NAME="720p"\n${secondPath}\n`;
}

function fakeBrowserPool(playlists) {
  let nextPlaylist = 0;
  const browser = {
    async newPage() {
      const page = new EventEmitter();
      for (const method of ['setJavaScriptEnabled', 'setCacheEnabled', 'setUserAgent', 'setViewport', 'evaluateOnNewDocument']) {
        page[method] = async () => {};
      }
      page.goto = async () => {
        const playlist = playlists[Math.min(nextPlaylist++, playlists.length - 1)];
        queueMicrotask(() => page.emit('response', {
          url: () => playlist.url,
          status: () => 200,
          text: async () => playlist.body,
        }));
      };
      page.close = async () => {};
      return page;
    },
  };
  return { acquire: async () => browser, close: async () => {} };
}

function responseAt(url, body, init) {
  const response = new Response(body, init);
  Object.defineProperty(response, 'url', { value: url.href });
  return response;
}

test('loads CineSrc sources, refreshes signed playlists, and proxies the selected HLS stream', async (t) => {
  const playlists = [
    { url: 'https://cinesrc.st/api/playlist/master-old.m3u8', body: masterPlaylist('/api/playlist/1080-old.m3u8', '/api/playlist/720-old.m3u8') },
    { url: 'https://cinesrc.st/api/playlist/master-fresh.m3u8', body: masterPlaylist('/api/playlist/1080-fresh.m3u8', '/api/playlist/720-fresh.m3u8') },
  ];
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    assert.equal(options.headers.Referer, 'https://cinesrc.st/');
    if (url.pathname === '/api/playlist/720-fresh.m3u8') {
      return responseAt(url, '#EXTM3U\n#EXT-X-MAP:URI="https://nebula.bright67.online/hls/movie/720p/init.mp4"\n#EXTINF:4,\nhttps://nebula.bright67.online/hls/movie/720p/segment.mp4\n', {
        headers: { 'Content-Type': 'application/vnd.apple.mpegurl' },
      });
    }
    if (url.pathname === '/hls/movie/720p/init.mp4' || url.pathname === '/hls/movie/720p/segment.mp4') {
      return responseAt(url, 'media-bytes', { headers: { 'Content-Type': 'video/mp4' } });
    }
    throw new Error(`Unexpected resource: ${url.href}`);
  };
  const server = createServer(null, {
    providerConfig: {
      initialProvider: 'Cinesrc',
      providers: [{
        name: 'Cinesrc',
        scheme: 'https',
        host: 'cinesrc.st',
        path: '/embed/{type}/{id}',
        parameters: { s: '{season}', e: '{episode}' },
      }],
    },
    browserPool: fakeBrowserPool(playlists),
    fetchImpl,
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const sources = await (await fetch(`${base}/sources?provider=cinesrc&type=movie&id=1492640`)).json();
  assert.deepEqual(sources.map(({ label }) => label), ['1080p', '720p']);

  const manifestResponse = await fetch(`${base}/manifest?provider=cinesrc&type=movie&id=1492640&source=${sources[1].id}`);
  assert.equal(manifestResponse.status, 200);
  const manifest = await manifestResponse.text();
  assert.match(manifest, /^#EXTM3U/);
  const initResource = manifest.match(/URI="([^"]+)"/)[1];
  assert.match(initResource, /^\/resource\//);

  const initResponse = await fetch(new URL(initResource, base));
  assert.equal(await initResponse.text(), 'media-bytes');
});