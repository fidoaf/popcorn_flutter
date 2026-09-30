const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { mediaFromQuery } = require('../src/player/mediaRequest');

const providers = new ProviderRegistry([{ id: 'vidsrcbuzz', label: 'VidSrc.buzz' }]);

test('parses movie ids and defaults to the registered provider', () => {
  assert.deepEqual(mediaFromQuery(new URLSearchParams('id=tt1375666'), providers), {
    providerId: 'vidsrcbuzz',
    type: 'movie',
    id: 'tt1375666',
    lang: 'en',
    sub: '1',
    season: '0',
    episode: '0',
  });
});

test('parses explicit audio language and subtitle preference', () => {
  assert.deepEqual(mediaFromQuery(new URLSearchParams('id=1084244&lang=fr&sub=0'), providers), {
    providerId: 'vidsrcbuzz',
    type: 'movie',
    id: '1084244',
    lang: 'fr',
    sub: '0',
    season: '0',
    episode: '0',
  });
});

test('parses TV season and episode', () => {
  assert.deepEqual(mediaFromQuery(new URLSearchParams('provider=vidsrcbuzz&type=tv&id=1399&season=2&episode=3'), providers), {
    providerId: 'vidsrcbuzz',
    type: 'tv',
    id: '1399',
    lang: 'en',
    sub: '1',
    season: '2',
    episode: '3',
  });
});

test('rejects unsupported providers and invalid episode numbers', () => {
  assert.throws(() => mediaFromQuery(new URLSearchParams('provider=unknown&id=1'), providers), { statusCode: 400 });
  assert.throws(() => mediaFromQuery(new URLSearchParams('type=tv&id=1&season=0&episode=2'), providers), { statusCode: 400 });
  assert.throws(() => mediaFromQuery(new URLSearchParams('id=1&lang=english'), providers), { statusCode: 400 });
  assert.throws(() => mediaFromQuery(new URLSearchParams('id=1&sub=2'), providers), { statusCode: 400 });
});