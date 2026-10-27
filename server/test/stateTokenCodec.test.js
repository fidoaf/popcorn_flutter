const test = require('node:test');
const assert = require('node:assert/strict');
const { PlayerAuth } = require('../src/player/playerAuth');
const { SourceRefStore } = require('../src/player/sourceRefStore');
const { StateTokenCodec } = require('../src/player/stateTokenCodec');
const { SubtitleRefStore } = require('../src/player/subtitleRefStore');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { ResourceProxy } = require('../src/player/resourceProxy');

const secret = 'a-long-test-secret-that-is-at-least-32-bytes';

test('encrypted state tokens survive new instances and reject tampering, type changes, and expiry', () => {
  const issuer = new StateTokenCodec(secret);
  const verifier = new StateTokenCodec(secret);
  const token = issuer.encode('example', { value: 'private value' }, 2000);

  assert.doesNotMatch(token, /private value/);
  assert.deepEqual(verifier.decode(token, 'example', 1999), { value: 'private value' });
  assert.equal(verifier.decode(token, 'different-type', 1999), null);
  assert.equal(verifier.decode(token, 'example', 2000), null);
  const [nonce, tag, encrypted] = token.split('.');
  const changedTag = `${tag[0] === 'A' ? 'B' : 'A'}${tag.slice(1)}`;
  assert.equal(verifier.decode(`${nonce}.${changedTag}.${encrypted}`, 'example', 1999), null);
});

test('playback sessions and provider references can be verified by fresh instances', () => {
  const issuerCodec = new StateTokenCodec(secret);
  const verifierCodec = new StateTokenCodec(secret);
  const issuer = new PlayerAuth(new Set(['api-token']), { tokenCodec: issuerCodec });
  const verifier = new PlayerAuth(new Set(['api-token']), { tokenCodec: verifierCodec });
  const session = issuer.createSession();
  const request = { headers: {} };
  const playerUrl = new URL(`https://server.example/player?session=${session}`);

  assert.equal(verifier.authorize(request, playerUrl), true);
  assert.equal(verifier.authorize(request, new URL('https://server.example/player?session=invalid')), false);

  const media = { type: 'tv', id: '42', season: '1', episode: '2', lang: 'en', sub: '0' };
  const sources = new SourceRefStore({ tokenCodec: issuerCodec });
  const sourceId = sources.add({ ref: 'provider-ref', token: 'provider-secret' }, 'test', media);
  assert.deepEqual(new SourceRefStore({ tokenCodec: verifierCodec }).get(sourceId, 'test', media), {
    ref: 'provider-ref',
    token: 'provider-secret',
    providerId: 'test',
    mediaKey: 'tv:42:1:2:en:0',
    expiresAt: sources.get(sourceId, 'test', media).expiresAt,
  });

  const subtitles = new SubtitleRefStore({ tokenCodec: issuerCodec });
  const subtitleId = subtitles.add('subtitle-ref', 'test');
  assert.deepEqual(new SubtitleRefStore({ tokenCodec: verifierCodec }).get(subtitleId), subtitles.get(subtitleId));

  const providers = new ProviderRegistry([{ id: 'test', label: 'Test', origin: 'https://media.example' }]);
  const firstProxy = new ResourceProxy({ providers, tokenCodec: issuerCodec });
  const manifest = firstProxy._rewriteManifest('#EXTM3U\n/segment.ts\n', 'https://media.example/master.m3u8', 'test');
  const resourceKey = manifest.match(/^\/resource\/([^\n]+)/m)[1];
  const secondProxy = new ResourceProxy({ providers, tokenCodec: verifierCodec });
  assert.deepEqual(secondProxy._getResource(resourceKey), {
    url: 'https://media.example/segment.ts',
    providerId: 'test',
  });
});