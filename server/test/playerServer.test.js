const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { createPlayerServer } = require('../src/player/playerServer');
const { createServer } = require('../server');
const { RedirectProvider } = require('../src/player/redirectProvider');

test('serves health, form, playback, and subtitles through injected services', async (t) => {
  const provider = {
    id: 'vidsrcbuzz',
    label: 'VidSrc.buzz',
    origin: 'https://vidsrc.buzz',
    async extract(media, selectedSource) {
      assert.equal(media.id, 'tt1375666');
      assert.equal(media.lang, 'fr');
      assert.equal(media.sub, '0');
      if (selectedSource) {
        assert.equal(selectedSource.ref, 'source-ref');
        assert.equal(selectedSource.token, 'source-token');
      }
      return { url: 'https://cdn.example/master.m3u8' };
    },
    async listSources(media) {
      assert.equal(media.id, 'tt1375666');
      return { token: 'source-token', sources: [{ ref: 'source-ref', name: 'Server SWM1', lang: 'English' }] };
    },
    async listSubtitles(media) {
      assert.equal(media.lang, 'fr');
      assert.equal(media.sub, '0');
      return [{ ref: 'subtitle-ref', label: 'English', lang: 'English' }];
    },
    async fetchSubtitle(ref) {
      assert.equal(ref, 'subtitle-ref');
      return new Response('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello', {
        headers: { 'Content-Type': 'text/vtt' },
      });
    },
  };
  const providers = new ProviderRegistry([
    provider,
    new RedirectProvider({
      id: 'nxsha',
      label: 'Nxsha',
      host: 'web.nxsha.app',
      path: '/embed/{type}/{id}/{season}/{episode}',
      parameters: { lang: '{language}', sub: '{subtitles}' },
    }),
  ]);
  const resourceProxy = {
    async serve(_request, response, url, providerId) {
      response.writeHead(200, { 'Content-Type': 'text/plain' });
      response.end(`${providerId}:${url}`);
    },
    async serveRegistered(_request, response, key) {
      response.writeHead(200, { 'Content-Type': 'text/plain' });
      response.end(key);
    },
  };
  const server = createPlayerServer({ providers, resourceProxy });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  assert.equal((await (await fetch(`${base}/health`)).text()), 'ok');
  const root = await (await fetch(`${base}/`)).text();
  assert.match(root, /Provider<select/);
  assert.match(root, /Audio language<select/);
  assert.match(root, /subtitle-preference/);
  assert.match(root, /<form id="media-form">/);

  const player = await (await fetch(`${base}/player?provider=vidsrcbuzz&id=tt1375666`)).text();
  assert.doesNotMatch(player, /<form id="media-form">/);
  assert.match(player, /const initialMedia = \{"providerId":"vidsrcbuzz"/);

  const manifest = await fetch(`${base}/manifest?provider=vidsrcbuzz&id=tt1375666&lang=fr&sub=0`);
  assert.equal(await manifest.text(), 'vidsrcbuzz:https://cdn.example/master.m3u8');

  const sources = await (await fetch(`${base}/sources?provider=vidsrcbuzz&id=tt1375666&lang=fr&sub=0`)).json();
  assert.equal(sources.length, 1);
  assert.equal(sources[0].label, 'Server SWM1');
  assert.equal(sources[0].ref, undefined);
  const selectedManifest = await fetch(`${base}/manifest?provider=vidsrcbuzz&id=tt1375666&lang=fr&sub=0&source=${sources[0].id}`);
  assert.equal(await selectedManifest.text(), 'vidsrcbuzz:https://cdn.example/master.m3u8');

  const redirect = await fetch(`${base}/player?provider=nxsha&type=tv&id=1399&season=2&episode=3&lang=fr&sub=0`, { redirect: 'manual' });
  assert.equal(redirect.status, 302);
  assert.equal(redirect.headers.get('location'), 'https://web.nxsha.app/embed/tv/1399/2/3?lang=fr&sub=0');

  const movieRedirect = await fetch(`${base}/player?provider=nxsha&type=movie&id=1248832&lang=en&sub=1`, { redirect: 'manual' });
  assert.equal(movieRedirect.status, 302);
  assert.equal(movieRedirect.headers.get('location'), 'https://web.nxsha.app/embed/movie/1248832?lang=en&sub=1');

  const tracks = await (await fetch(`${base}/subtitles?provider=vidsrcbuzz&id=tt1375666&lang=fr&sub=0`)).json();
  assert.equal(tracks.length, 1);
  const subtitle = await fetch(`${base}/subtitle/${tracks[0].id}`);
  assert.match(await subtitle.text(), /^WEBVTT/);

  const invalid = await fetch(`${base}/manifest?provider=missing&id=tt1375666`);
  assert.equal(invalid.status, 400);
});

test('registers configured providers and redirects providers without server extractors', async (t) => {
  const server = createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const root = await (await fetch(`${base}/`)).text();
  for (const providerId of ['vidsrcbuzz', 'nxsha', 'cinesrc', 'onlypelis', 'vidsrcsbs', 'vidsrcir', 'vidlux', 'vidsrcme']) {
    assert.match(root, new RegExp(`value="${providerId}"`));
  }
  assert.doesNotMatch(root, /value="render"/);

  const redirectProviders = {
    vidsrcsbs: 'https://vidsrc.sbs',
    vidsrcir: 'https://vidsrc.ir',
    vidlux: 'https://vidlux.xyz',
    vidsrcme: 'https://vidsrcme.ru',
  };
  for (const [providerId, origin] of Object.entries(redirectProviders)) {
    const response = await fetch(`${base}/player?provider=${providerId}&id=1248832`, { redirect: 'manual' });
    assert.equal(response.status, 302);
    assert.equal(response.headers.get('location'), `${origin}/embed/movie/1248832?lang=en&sub=1`);
  }

  const cinesrcMovie = await fetch(`${base}/player?provider=cinesrc&id=1248832`, { redirect: 'manual' });
  assert.equal(cinesrcMovie.status, 200);
  assert.match(await cinesrcMovie.text(), /const initialMedia = \{"providerId":"cinesrc"/);

  const cinesrcTv = await fetch(`${base}/player?provider=cinesrc&type=tv&id=1399&season=2&episode=3`, { redirect: 'manual' });
  assert.equal(cinesrcTv.status, 200);
  assert.match(await cinesrcTv.text(), /"type":"tv","id":"1399","lang":"en","sub":"1","season":"2","episode":"3"/);

  const nxshaPage = await fetch(`${base}/player?provider=nxsha&id=1248832`, { redirect: 'manual' });
  assert.equal(nxshaPage.status, 200);
  assert.match(await nxshaPage.text(), /const initialMedia = \{"providerId":"nxsha"/);

  const onlyPelisPage = await fetch(`${base}/player?provider=onlypelis&id=977942`, { redirect: 'manual' });
  assert.equal(onlyPelisPage.status, 200);
  assert.match(await onlyPelisPage.text(), /const initialMedia = \{"providerId":"onlypelis","type":"movie","id":"977942"/);

  const onlyPelisEpisodePage = await fetch(`${base}/player?provider=onlypelis&type=tv&id=1234&season=1&episode=1`, { redirect: 'manual' });
  assert.equal(onlyPelisEpisodePage.status, 200);
  assert.match(await onlyPelisEpisodePage.text(), /"providerId":"onlypelis","type":"tv","id":"1234"/);

  const response = await fetch(`${base}/player?provider=render&id=123`, { redirect: 'manual' });
  assert.equal(response.status, 400);
});

test('builds providers from configurable paths and query parameters', async (t) => {
  const server = createServer(null, {
    providerConfig: {
      initialProvider: 'Custom Source',
      providers: [
        { name: 'Render', host: 'popcorn-flutter.onrender.com', path: '/player' },
        { name: 'Vidsrc.buzz', host: 'vidsrc.buzz', path: '/embed/{type}/{id}' },
        {
          name: 'Custom Source',
          scheme: 'https',
          host: 'embed.example',
          path: '/watch/{type}/{id}/{season}/{episode}',
          parameters: { language: '{language}', captions: '{subtitles}', media: '{id}', mode: 'embed' },
        },
      ],
    },
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const root = await (await fetch(`${base}/`)).text();
  assert.match(root, /value="customsource" selected/);
  assert.doesNotMatch(root, /value="render"/);

  const redirect = await fetch(`${base}/player?id=42`, { redirect: 'manual' });
  assert.equal(redirect.status, 302);
  assert.equal(redirect.headers.get('location'), 'https://embed.example/watch/movie/42?language=en&captions=1&media=42&mode=embed');
});