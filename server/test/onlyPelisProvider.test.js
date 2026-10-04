const test = require('node:test');
const assert = require('node:assert/strict');
const { OnlyPelisProvider, parseHlsUrl, parseSubtitleTracks } = require('../src/player/onlyPelisProvider');
const { createProviderRegistry } = require('../src/player/providerFactory');

test('resolves the HLS source from the OnlyPelis player response', async () => {
  const calls = [];
  const streamUrl = 'https://spark.9bg.net/path-token/manifest-token/video.m3u8';
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    calls.push({ url, options });
    if (url.hostname === 'www.themoviedb.org') {
      return new Response('<meta property="og:title" content="El hombre que desafió al rey">');
    }
    if (url.hostname === 'onlypelis.com' && url.pathname === '/' && url.searchParams.get('s')) {
      return new Response('<a href="/pelicula/el-hombre-que-desafio-al-rey/">Ver detalles</a>');
    }
    if (url.pathname === '/pelicula/el-hombre-que-desafio-al-rey/') {
      return new Response('<body class="single postid-13942"><h1>El hombre que desafió al rey (2026)</h1></body>');
    }
    if (url.pathname === '/wp-admin/admin-ajax.php') {
      return Response.json({ embed_url: 'https://paulinito.com/player/player-key/' });
    }
    if (url.pathname === '/player/player-key/') {
      return new Response(`<script>var config = { sources: [{ "file": "${streamUrl}", "label": "HD", "type": "application/x-mpegURL" }] };</script>`);
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new OnlyPelisProvider({ fetchImpl });
  const result = await provider.extract({ type: 'movie', id: '977942', lang: 'en' });

  assert.deepEqual(result, { url: streamUrl, type: 'hls' });
  const tmdbRequest = calls.find(({ url }) => url.hostname === 'www.themoviedb.org');
  assert.equal(tmdbRequest.url.pathname, '/movie/977942');
  assert.equal(tmdbRequest.url.searchParams.get('language'), 'es-ES');
  assert.equal(calls.find(({ url }) => url.hostname === 'onlypelis.com' && url.searchParams.has('s')).url.searchParams.get('s'), 'El hombre que desafió al rey');
  const playerRequest = calls.find(({ url }) => url.pathname === '/wp-admin/admin-ajax.php');
  assert.equal(playerRequest.options.method, 'POST');
  assert.equal(playerRequest.options.body.toString(), 'action=doo_player_ajax&post=13942&nume=1&type=movie');
});

test('resolves TV episodes using the episode post ID and tv player type', async () => {
  const calls = [];
  const streamUrl = 'https://amber.9bg.net/episode-token/manifest-token/video.m3u8';
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    calls.push({ url, options });
    if (url.hostname === 'www.themoviedb.org') return new Response('<meta property="og:title" content="Lucky">');
    if (url.hostname === 'onlypelis.com' && url.pathname === '/' && url.searchParams.get('s')) {
      return new Response('<a href="/serie/lucky/">Ver detalles de Lucky</a>');
    }
    if (url.pathname === '/serie/lucky/') {
      return new Response('<body class="single postid-12000"><h1>Lucky (2024)</h1><a href="/episodios/lucky-1x1/">Aang</a></body>');
    }
    if (url.pathname === '/episodios/lucky-1x1/') {
      return new Response('<body class="single postid-12183"><h1>Lucky: 1x1</h1></body>');
    }
    if (url.pathname === '/wp-admin/admin-ajax.php') {
      return Response.json({ embed_url: 'https://paulinito.com/player/episode-key/' });
    }
    if (url.pathname === '/player/episode-key/') {
      return new Response(`<script>var config = { sources: [{ "file": "${streamUrl}" }] };</script>`);
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };

  const provider = new OnlyPelisProvider({ fetchImpl });
  const result = await provider.extract({ type: 'tv', id: '1234', season: '1', episode: '1', lang: 'en' });

  assert.deepEqual(result, { url: streamUrl, type: 'hls' });
  assert.equal(calls.find(({ url }) => url.pathname === '/episodios/lucky-1x1/').url.pathname, '/episodios/lucky-1x1/');
  assert.equal(calls.find(({ url }) => url.pathname === '/wp-admin/admin-ajax.php').options.body.toString(), 'action=doo_player_ajax&post=12183&nume=1&type=tv');
});

test('lists caption tracks, ignores thumbnails, and serves SRT as WebVTT', async () => {
  const calls = [];
  const subtitleUrl = 'https://amber.9bg.net/subtitle-token/subtitles.srt';
  const playerHtml = `<script>var config = { tracks: [{ "file": "${subtitleUrl}", "label": "Español", "kind": "captions", "language": "es" }, { "file": "https://amber.9bg.net/thumbs.vtt", "kind": "thumbnails" }] };</script>`;
  const fetchImpl = async (input, options) => {
    const url = new URL(input);
    calls.push({ url, options });
    if (url.hostname === 'www.themoviedb.org') return new Response('<meta property="og:title" content="Lucky">');
    if (url.hostname === 'onlypelis.com' && url.pathname === '/' && url.searchParams.get('s')) return new Response('<a href="/serie/lucky/">Lucky</a>');
    if (url.pathname === '/serie/lucky/') return new Response('<body class="postid-12000"><h1>Lucky (2024)</h1><a href="/episodios/lucky-1x1/">Aang</a></body>');
    if (url.pathname === '/episodios/lucky-1x1/') return new Response('<body class="postid-12183"><h1>Lucky: 1x1</h1></body>');
    if (url.pathname === '/wp-admin/admin-ajax.php') return Response.json({ embed_url: 'https://paulinito.com/player/player-key/' });
    if (url.pathname === '/player/player-key/') return new Response(playerHtml);
    if (url.href === subtitleUrl) {
      return new Response('1\n00:00:01,000 --> 00:00:02,000\nHola\n', { headers: { 'Content-Type': 'application/x-subrip' } });
    }
    throw new Error(`Unexpected request: ${url.href}`);
  };
  const provider = new OnlyPelisProvider({ fetchImpl });
  const media = { type: 'tv', id: '1234', season: '1', episode: '1', lang: 'en' };

  const subtitles = await provider.listSubtitles(media);
  assert.deepEqual(subtitles, [{ ref: subtitleUrl, label: 'Español', lang: 'es' }]);
  const response = await provider.fetchSubtitle(subtitles[0].ref);
  assert.match(await response.text(), /^WEBVTT\n\n00:00:01\.000 --> 00:00:02\.000\nHola/);
  assert.equal(response.headers.get('content-type'), 'text/vtt; charset=utf-8');
  assert.equal(calls.at(-1).options.headers.Referer, 'https://paulinito.com/');
});

test('rejects unsupported media IDs, player hosts, and stream hosts', async () => {
  const provider = new OnlyPelisProvider({
    fetchImpl: async (input) => {
      const url = new URL(input);
      if (url.hostname === 'www.themoviedb.org') return new Response('<meta property="og:title" content="Movie title">');
      if (url.hostname === 'onlypelis.com' && url.pathname === '/') return new Response('<a href="/pelicula/movie-title/">Movie title</a>');
      if (url.pathname === '/pelicula/movie-title/') return new Response('<body class="postid-44"><h1>Movie title</h1></body>');
      if (url.pathname === '/wp-admin/admin-ajax.php') return Response.json({ embed_url: 'https://evil.example/player/key/' });
      throw new Error(`Unexpected request: ${url.href}`);
    },
  });
  await assert.rejects(provider.extract({ type: 'movie', id: 'tt12345' }), /numeric TMDB ID/);
  await assert.rejects(provider.extract({ type: 'episode', id: '13946' }), /supports movies and TV episodes only/);
  await assert.rejects(provider.extract({ type: 'movie', id: '13946' }), /unsupported player URL/);
  assert.throws(() => parseHlsUrl('<script>var config = { "sources": [{ "file": "https://evil.example/video.m3u8" }] };</script>'), /unsupported HLS URL/);
  assert.deepEqual(parseSubtitleTracks('<script>var config = { tracks: [{ "file": "https://evil.example/sub.srt", "kind": "captions" }] };</script>'), []);
});

test('registers OnlyPelis as a dedicated provider', () => {
  const providers = createProviderRegistry({
    providerConfig: { providers: [{ name: 'OnlyPelis' }] },
    fetchImpl: async () => { throw new Error('Not expected'); },
  });
  assert.equal(providers.get('onlypelis').label, 'OnlyPelis');
});