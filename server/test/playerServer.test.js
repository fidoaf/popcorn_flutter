const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { createPlayerServer } = require('../src/player/playerServer');
const { createServer } = require('../server');
const { RedirectProvider } = require('../src/player/redirectProvider');
const { renderPlayerPage } = require('../src/player/playerPage');
const vm = require('node:vm');

test('provider catalog exposes configured choices and default to the app', async (t) => {
  const providers = new ProviderRegistry([
    { id: 'direct', label: 'Direct' },
    new RedirectProvider({ id: 'external', label: 'External', host: 'example.com' }),
  ], 'external');
  const server = createPlayerServer({ providers, resourceProxy: {} });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const response = await fetch(`http://127.0.0.1:${server.address().port}/providers`);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.deepEqual(await response.json(), {
    providers: [{ id: 'external', label: 'External' }, { id: 'direct', label: 'Direct' }],
    defaultProvider: 'external',
  });
});

test('restores a hosted session with fresh track IDs and reports settings, progress and seeks', async () => {
  const media = { providerId: 'vidsrcbuzz', type: 'movie', id: '42', lang: 'es', sub: '1' };
  const sourceKey = JSON.stringify(['Server 1', 'Spanish']);
  const subtitleKey = JSON.stringify(['Spanish', 'Spanish']);
  const query = new URLSearchParams({ resume: '120', resumeSource: sourceKey, resumeSubtitles: subtitleKey, parentOrigin: 'https://app.example' });
  const elements = new Map();
  function element() {
    const listeners = new Map();
    return {
      value: '', options: [], dataset: {}, hidden: false, currentTime: 0, duration: 600, ended: false,
      get selectedOptions() { return this.options.filter((option) => option.value === this.value); },
      addEventListener(event, callback) {
        if (!listeners.has(event)) listeners.set(event, []);
        listeners.get(event).push(callback);
      },
      dispatchEvent(event) { this.dispatch(event.type); },
      dispatch(event) { for (const callback of listeners.get(event) || []) callback(); },
      replaceChildren(...options) { this.options = options; this.value = options[0]?.value || ''; },
      add(option) { this.options.push(option); },
      appendChild(option) { this.options.push(option); },
      remove() {}, pause() {}, load() {}, removeAttribute() {},
      canPlayType() { return true; },
      async play() {},
      track: {},
    };
  }
  const document = {
    addEventListener() {}, querySelectorAll() { return []; },
    createElement() { return element(); },
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) elements.set(id, element());
      return elements.get(id);
    },
  };
  const messages = [];
  const nativeMessages = [];
  const navigations = [];
  const windowListeners = new Map();
  let now = 10000;
  vm.runInNewContext(renderPlayerPage(media, { showForm: false, session: 'playback-session' }).match(/<script>([\s\S]*?)<\/script>/)[1], {
    document, URLSearchParams, setTimeout: () => 0, clearTimeout() {}, Event: class { constructor(type) { this.type = type; } },
    Date: { now: () => now },
    Option: function Option(label, value) { return { textContent: label, value, dataset: {} }; },
    fetch: async (url) => ({ ok: true, json: async () => url.startsWith('/sources')
      ? [{ id: 'fresh-source', label: 'Server 1', language: 'Spanish' }]
      : [{ id: 'fresh-subtitle', label: 'Spanish', language: 'Spanish' }] }),
    window: {
      location: { search: '?' + query, assign(url) { navigations.push(url); } },
      parent: { postMessage(message, origin) { assert.equal(origin, 'https://app.example'); messages.push(message); } },
      flutter_inappwebview: { callHandler(name, message) { assert.equal(name, 'popcornPlayback'); nativeMessages.push(message); } },
      addEventListener(name, callback) { windowListeners.set(name, callback); },
    },
  });
  await new Promise((resolve) => setImmediate(resolve));
  const video = elements.get('video');
  assert.equal(elements.get('source').value, 'fresh-source');
  assert.equal(elements.get('subtitles').value, 'fresh-subtitle');
  assert.equal(video.options[0].src, '/subtitle/fresh-subtitle?session=playback-session');
  assert.match(video.src, /session=playback-session/);
  video.dispatch('loadedmetadata');
  assert.equal(video.currentTime, 120);
  video.dispatch('seeked');
  assert.equal(messages.at(-1).event, 'seeked');
  assert.equal(messages.at(-1).session.positionSeconds, 120);
  assert.equal(messages.at(-1).session.source, sourceKey);
  assert.equal(messages.at(-1).session.subtitles, subtitleKey);
  video.currentTime = 130;
  video.dispatch('timeupdate');
  const count = messages.length;
  video.currentTime = 131;
  video.dispatch('timeupdate');
  assert.equal(messages.length, count);
  now += 5000;
  video.dispatch('timeupdate');
  assert.equal(messages.at(-1).session.positionSeconds, 131);
  video.currentTime = 240;
  video.dispatch('seeked');
  assert.equal(messages.at(-1).session.positionSeconds, 240);
  elements.get('subtitles').value = '';
  elements.get('subtitles').dispatch('change');
  assert.equal(messages.at(-1).session.subtitles, '');
  elements.get('playback-language').value = 'fr';
  elements.get('playback-language').dispatch('change');
  assert.equal(messages.at(-1).session.language, 'fr');
  const languageUrl = new URL(navigations.at(-1), 'https://player.example');
  assert.equal(languageUrl.searchParams.get('resume'), '240');
  assert.equal(languageUrl.searchParams.get('lang'), 'fr');
  assert.equal(languageUrl.searchParams.get('session'), 'playback-session');
  elements.get('provider').value = 'nxsha';
  elements.get('provider').dispatch('change');
  assert.equal(messages.at(-1).session.provider, 'nxsha');
  assert.equal(messages.at(-1).session.source, '');
  assert.equal(new URL(navigations.at(-1), 'https://player.example').searchParams.has('resumeSource'), false);
  video.ended = true;
  video.dispatch('ended');
  windowListeners.get('pagehide')();
  assert.equal(messages.at(-1).session.positionSeconds, 0);
  assert.equal(nativeMessages.length, messages.length);
});

test('player provider selector precedes source and switches providers with current media settings', () => {
  const media = { providerId: 'vidsrcbuzz', type: 'tv', id: '1399', season: '2', episode: '3', lang: 'fr', sub: '0' };
  const page = renderPlayerPage(media, {
    showForm: false,
    providers: [{ id: 'vidsrcbuzz', label: 'VidSrc.buzz' }, { id: 'nxsha', label: 'Nxsha' }],
  });
  assert.match(page, /<label for="provider">Provider<select id="provider" disabled><option value="vidsrcbuzz" selected>VidSrc.buzz<\/option><option value="nxsha">Nxsha<\/option><\/select><\/label><label for="playback-language"/);
  assert.doesNotMatch(page, /<form id="media-form">/);
  const elements = new Map();
  const document = {
    addEventListener() {},
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) {
        const listeners = new Map();
        elements.set(id, {
          value: '',
          dataset: {},
          disabled: true,
          addEventListener(event, callback) { listeners.set(event, callback); },
          dispatch(event) { listeners.get(event)?.(); },
          replaceChildren() {},
          pause() {},
          removeAttribute() {},
          load() {},
          canPlayType() { return true; },
        });
      }
      return elements.get(id);
    },
    querySelectorAll() { return []; },
  };
  const navigations = [];
  const script = page.match(/<script>([\s\S]*?)<\/script>/)[1];
  vm.runInNewContext(script, {
    document, setTimeout: () => 0, clearTimeout() {},
    URLSearchParams,
    Option: function Option() {},
    fetch: () => new Promise(() => {}),
    window: { addEventListener() {}, location: { assign(url) { navigations.push(url); } } },
  });
  const provider = elements.get('provider');
  assert.equal(provider.value, 'vidsrcbuzz');
  assert.equal(provider.disabled, false);
  elements.get('source').value = 'old-provider-source';
  provider.value = 'nxsha';
  provider.dispatch('change');
  assert.equal(navigations.length, 1);
  const url = new URL(navigations[0], 'http://localhost');
  assert.equal(url.pathname, '/player');
  assert.deepEqual(Object.fromEntries(url.searchParams), {
    provider: 'nxsha', type: 'tv', id: '1399', lang: 'fr', sub: '0', season: '2', episode: '3',
  });
});

test('player shows a circular loader while buffering and seeking until video is ready', () => {
  const page = renderPlayerPage(null, { showForm: false });
  assert.match(page, /id="video-loading" role="status" aria-label="Loading video" hidden/);
  assert.match(page, /@keyframes video-loading-spin/);
  assert.match(page, /pointer-events:none/);
  const elements = new Map();
  const document = {
    addEventListener() {},
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) {
        const listeners = new Map();
        elements.set(id, {
          hidden: id === 'video-loading' || id === 'retry',
          dataset: {},
          readyState: 2,
          seeking: false,
          addEventListener(event, callback) {
            if (!listeners.has(event)) listeners.set(event, []);
            listeners.get(event).push(callback);
          },
          dispatch(event) {
            for (const callback of listeners.get(event) || []) callback();
          },
        });
      }
      return elements.get(id);
    },
    querySelectorAll() { return []; },
  };
  const script = page.match(/<script>([\s\S]*?)<\/script>/)[1];
  vm.runInNewContext(script, { document, URLSearchParams, setTimeout: () => 0, clearTimeout() {}, window: { location: {}, addEventListener() {} } });
  const video = elements.get('video');
  const loader = elements.get('video-loading');
  assert.equal(loader.hidden, true);
  video.dispatch('loadstart');
  assert.equal(loader.hidden, false);
  video.readyState = 3;
  video.dispatch('canplay');
  assert.equal(loader.hidden, true);
  video.dispatch('waiting');
  assert.equal(loader.hidden, false);
  video.dispatch('playing');
  assert.equal(loader.hidden, true);
  video.seeking = true;
  video.dispatch('seeking');
  video.dispatch('canplay');
  assert.equal(loader.hidden, false);
  video.seeking = false;
  video.readyState = 2;
  video.dispatch('seeked');
  assert.equal(loader.hidden, false);
  video.readyState = 3;
  video.dispatch('canplay');
  assert.equal(loader.hidden, true);
  video.dispatch('seeking');
  video.dispatch('seeked');
  assert.equal(loader.hidden, true);
  video.dispatch('waiting');
  video.dispatch('ended');
  assert.equal(loader.hidden, true);
  video.dispatch('waiting');
  video.dispatch('error');
  assert.equal(loader.hidden, true);
  assert.equal(elements.get('retry').hidden, false);
  video.dispatch('waiting');
  assert.equal(loader.hidden, true);
});

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
  assert.equal(redirect.status, 200);
  assert.match(await redirect.text(), /const embedUrl = "https:\/\/web.nxsha.app\/embed\/tv\/1399\/2\/3\?lang=fr&sub=0"/);

  const movieRedirect = await fetch(`${base}/player?provider=nxsha&type=movie&id=1248832&lang=en&sub=1`, { redirect: 'manual' });
  assert.equal(movieRedirect.status, 200);
  assert.match(await movieRedirect.text(), /const embedUrl = "https:\/\/web.nxsha.app\/embed\/movie\/1248832\?lang=en&sub=1"/);

  const tracks = await (await fetch(`${base}/subtitles?provider=vidsrcbuzz&id=tt1375666&lang=fr&sub=0`)).json();
  assert.equal(tracks.length, 1);
  const subtitle = await fetch(`${base}/subtitle/${tracks[0].id}`);
  assert.match(await subtitle.text(), /^WEBVTT/);

  const invalid = await fetch(`${base}/manifest?provider=missing&id=tt1375666`);
  assert.equal(invalid.status, 400);
});

test('registers configured providers and retains the settings shell for redirect providers', async (t) => {
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
    assert.equal(response.status, 200);
    const page = await response.text();
    assert.ok(page.includes(`const embedUrl = "${origin}/embed/movie/1248832?lang=en&sub=1"`));
    assert.match(page, /id="settings-toggle"/);
    assert.match(page, /id="provider-frame"/);
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
  assert.equal(redirect.status, 200);
  assert.match(await redirect.text(), /const embedUrl = "https:\/\/embed.example\/watch\/movie\/42\?language=en&captions=1&media=42&mode=embed"/);
});

test('redirect gear opens settings and preserves media when preferences or providers change', () => {
  const media = { providerId: 'external', type: 'tv', id: '1399', season: '2', episode: '3', lang: 'fr', sub: '1' };
  const embedUrl = 'https://embed.example/tv/1399/2/3?lang=fr&sub=1';
  const page = renderPlayerPage(media, {
    showForm: false,
    embedUrl,
    providers: [{ id: 'external', label: 'External' }, { id: 'vidsrcbuzz', label: 'VidSrc.buzz' }],
  });
  const settingsStart = page.indexOf('<section id="playback-settings"');
  const settingsEnd = page.indexOf('</section>', settingsStart);
  for (const id of ['provider', 'source', 'playback-language', 'subtitles']) {
    assert.ok(page.indexOf(`id="${id}"`, settingsStart) < settingsEnd);
  }
  const elements = new Map();
  const documentListeners = new Map();
  const navigations = [];
  const messages = [];
  const document = {
    querySelectorAll() { return []; },
    addEventListener(event, callback) { documentListeners.set(event, callback); },
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) {
        const listeners = new Map();
        elements.set(id, {
          value: '', hidden: true, disabled: true, options: [], dataset: {},
          addEventListener(event, callback) { listeners.set(event, callback); },
          dispatch(event) { listeners.get(event)?.(); },
          replaceChildren(...options) { this.options = options; this.value = options[0]?.value || ''; },
          focus() { this.focused = true; },
        });
      }
      return elements.get(id);
    },
  };
  vm.runInNewContext(page.match(/<script>([\s\S]*?)<\/script>/)[1], {
    document, URLSearchParams, setTimeout: () => 0, clearTimeout() {},
    Option: function Option(label, value) { return { textContent: label, value, dataset: {} }; },
    fetch() { assert.fail('Redirect embeds must not request manifests or track catalogs'); },
    window: {
      addEventListener() {},
      parent: { postMessage(message) { messages.push(message); } },
      location: { search: '?resume=95&parentOrigin=https%3A%2F%2Fapp.example&title=Game+of+Thrones&year=2011', assign(url) { navigations.push(new URL(url, 'https://player.example')); } },
    },
  });
  assert.equal(elements.get('now-playing').textContent, 'Game of Thrones 2011 · S02 E03');
  assert.equal(elements.get('provider-frame').src, embedUrl);
  assert.equal(elements.get('video').hidden, true);
  assert.equal(elements.get('video-loading').hidden, true);
  assert.equal(elements.get('source').disabled, true);
  assert.equal(elements.get('subtitles').disabled, false);
  const toggle = elements.get('settings-toggle');
  const panel = elements.get('playback-settings');
  assert.equal(toggle.hidden, false);
  toggle.dispatch('click');
  assert.equal(panel.hidden, false);
  assert.equal(toggle.ariaExpanded, 'true');
  assert.equal(elements.get('settings-close').focused, true);
  documentListeners.get('keydown')({ key: 'Escape' });
  assert.equal(panel.hidden, true);
  assert.equal(toggle.focused, true);
  toggle.dispatch('click');
  elements.get('settings-close').dispatch('click');
  assert.equal(panel.hidden, true);
  elements.get('playback-language').value = 'es';
  elements.get('playback-language').dispatch('change');
  assert.equal(navigations.at(-1).searchParams.get('lang'), 'es');
  elements.get('subtitles').value = '0';
  elements.get('subtitles').dispatch('change');
  assert.equal(navigations.at(-1).searchParams.get('sub'), '0');
  assert.equal(messages.at(-1).session.subtitles, '');
  elements.get('provider').value = 'vidsrcbuzz';
  elements.get('provider').dispatch('change');
  assert.deepEqual(Object.fromEntries(navigations.at(-1).searchParams), {
    provider: 'vidsrcbuzz', type: 'tv', id: '1399', season: '2', episode: '3', lang: 'es', sub: '0',
    resume: '95', resumeSubtitles: '', parentOrigin: 'https://app.example', title: 'Game of Thrones', year: '2011',
  });
});

test('first play waits for a user gesture, then unmutes, enters fullscreen and starts playback', async () => {
  const media = { providerId: 'vidsrcbuzz', type: 'movie', id: '42', lang: 'en', sub: '1' };
  const page = renderPlayerPage(media, { showForm: false });
  assert.match(page, /id="video" playsinline controlslist="nofullscreen" hidden/);
  assert.match(page, /id="start-playback" type="button" title="Play" aria-label="Play" hidden><span class="play-icon" aria-hidden="true"><\/span><span class="visually-hidden">Play<\/span><\/button>/);
  assert.doesNotMatch(page, /id="video" controls/);
  const elements = new Map();
  const listeners = new Map();
  const video = {
    muted: false,
    controls: false,
    hidden: true,
    readyState: 0,
    addEventListener(event, callback) {
      if (!listeners.has(event)) listeners.set(event, []);
      listeners.get(event).push(callback);
    },
    dispatch(event) { for (const callback of listeners.get(event) || []) callback(); },
    removeAttribute() {}, pause() {}, load() {}, canPlayType() { return true; },
    play() { this.playCalls = (this.playCalls || 0) + 1; return Promise.resolve(); },
  };
  const startButton = {
    hidden: true,
    addEventListener(event, callback) { this.onClick = callback; },
  };
  let fullscreenCalls = 0;
  const document = {
    addEventListener() {}, querySelectorAll() { return []; },
    getElementById(id) {
      if (id === 'media-form') return null;
      if (!elements.has(id)) {
        elements.set(id, id === 'video' ? video : id === 'start-playback' ? startButton : {
          value: '', dataset: {}, hidden: true, disabled: true, addEventListener() {}, replaceChildren() {}, pause() {}, removeAttribute() {}, load() {}, canPlayType() { return true; },
        });
      }
      return elements.get(id);
    },
  };
  const script = page.match(/<script>([\s\S]*?)<\/script>/)[1];
  vm.runInNewContext(script, {
    document, URLSearchParams, setTimeout: () => 0, clearTimeout() {}, Event: class { constructor(type) { this.type = type; } },
    Option: function Option(label, value) { return { textContent: label, value, dataset: {} }; },
    fetch: () => new Promise(() => {}),
    window: { location: { search: '', assign() {} }, parent: { postMessage() {} }, addEventListener() {} },
  });
  assert.equal(video.playCalls || 0, 0);
  assert.equal(video.controls, false);
  const container = elements.get('video-container');
  container.requestFullscreen = () => { fullscreenCalls += 1; return Promise.resolve(); };
  startButton.onClick();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(video.muted, false);
  assert.equal(video.controls, true);
  assert.equal(fullscreenCalls, 1);
  assert.equal(video.playCalls, 1);
  assert.equal(startButton.hidden, true);
});