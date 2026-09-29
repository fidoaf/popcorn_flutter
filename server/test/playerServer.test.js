const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { createPlayerServer } = require('../src/player/playerServer');

test('serves health, form, playback, and subtitles through injected services', async (t) => {
  const provider = {
    id: 'vidsrcbuzz',
    label: 'VidSrc.buzz',
    origin: 'https://vidsrc.buzz',
    async extract(media) {
      assert.equal(media.id, 'tt1375666');
      return { url: 'https://cdn.example/master.m3u8' };
    },
    async listSubtitles() {
      return [{ ref: 'subtitle-ref', label: 'English', lang: 'English' }];
    },
    async fetchSubtitle(ref) {
      assert.equal(ref, 'subtitle-ref');
      return new Response('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello', {
        headers: { 'Content-Type': 'text/vtt' },
      });
    },
  };
  const providers = new ProviderRegistry([provider]);
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
  assert.match(root, /<form id="media-form">/);

  const player = await (await fetch(`${base}/player?provider=vidsrcbuzz&id=tt1375666`)).text();
  assert.doesNotMatch(player, /<form id="media-form">/);
  assert.match(player, /const initialMedia = \{"providerId":"vidsrcbuzz"/);

  const manifest = await fetch(`${base}/manifest?provider=vidsrcbuzz&id=tt1375666`);
  assert.equal(await manifest.text(), 'vidsrcbuzz:https://cdn.example/master.m3u8');

  const tracks = await (await fetch(`${base}/subtitles?provider=vidsrcbuzz&id=tt1375666`)).json();
  assert.equal(tracks.length, 1);
  const subtitle = await fetch(`${base}/subtitle/${tracks[0].id}`);
  assert.match(await subtitle.text(), /^WEBVTT/);

  const invalid = await fetch(`${base}/manifest?provider=missing&id=tt1375666`);
  assert.equal(invalid.status, 400);
});