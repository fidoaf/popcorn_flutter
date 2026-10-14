const test = require('node:test');
const assert = require('node:assert/strict');
const { createPlayerServer } = require('../src/player/playerServer');
const { resolveJustWatchProviderLinks } = require('../src/player/justWatchProviderLinks');

test('returns JustWatch offer clickouts keyed by provider ID', async (t) => {
  const context = {
    data: [
      { schema: 'clickout_context', data: { provider: 'Amazon Video', providerId: 10, monetizationType: 'RENT' } },
      { schema: 'title_context', data: { titleId: 1265001, objectType: 'movie' } },
    ],
  };
  const clickout = new URL('https://click.justwatch.com/a');
  clickout.searchParams.set('cx', Buffer.from(JSON.stringify(context)).toString('base64'));
  clickout.searchParams.set('r', 'https://app.primevideo.com/detail?id=test');
  const requests = [];
  const fetchImpl = async (url) => {
    requests.push(new URL(url));
    const body = requests.length === 1
      ? '<a href="https://www.justwatch.com/es/pelicula/spider-man-un-nuevo-dia"><span>Spider-Man: Un nuevo día</span><span>(2026)</span></a>'
      : `<a href="${clickout.href.replace(/&/g, '&amp;')}">Amazon Video</a>`;
    return { ok: true, status: 200, text: async () => body };
  };
  const providers = { providers: new Map(), list: () => [], get() { throw new Error('unused'); } };
  const resourceProxy = { async serve() {}, async serveRegistered() {} };
  const server = createPlayerServer({ providers, resourceProxy, fetchImpl });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const base = `http://127.0.0.1:${server.address().port}`;
  const response = await fetch(`${base}/watch-providers?type=movie&title=Spider-Man%3A%20Brand%20New%20Day&year=2026&region=ES`);

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), '*');
  assert.deepEqual(await response.json(), { 10: clickout.href });
  assert.equal(requests[0].pathname, '/es/buscar');
  assert.equal(requests[1].pathname, '/es/pelicula/spider-man-un-nuevo-dia');
});

test('keeps CORS headers on JustWatch failures, validation errors and preflight responses', async (t) => {
  const providers = { providers: new Map(), list: () => [] };
  const resourceProxy = {};
  const fetchImpl = async () => ({ ok: false, status: 403 });
  const server = createPlayerServer({ providers, resourceProxy, fetchImpl });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const endpoint = `http://127.0.0.1:${server.address().port}/watch-providers`;

  const failure = await fetch(`${endpoint}?type=tv&title=Solar%20Opposites&region=GB&year=2020`, {
    headers: { Origin: 'http://localhost:3000' },
  });
  assert.equal(failure.status, 502);
  assert.equal(failure.headers.get('access-control-allow-origin'), '*');
  assert.deepEqual(await failure.json(), { error: 'Unable to load JustWatch provider links' });

  const invalid = await fetch(endpoint);
  assert.equal(invalid.status, 400);
  assert.equal(invalid.headers.get('access-control-allow-origin'), '*');

  const preflight = await fetch(endpoint, { method: 'OPTIONS', headers: { Origin: 'http://localhost:3000' } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), '*');
  assert.equal(preflight.headers.get('access-control-allow-methods'), 'GET, OPTIONS');
});

test('maps TMDB GB availability to the JustWatch UK TV site', async () => {
  const clickout = new URL('https://click.justwatch.com/a');
  clickout.searchParams.set('cx', Buffer.from(JSON.stringify({ data: [{ data: { providerId: 337 } }] })).toString('base64'));
  clickout.searchParams.set('r', 'https://www.disneyplus.com/series/solar-opposites');
  const requests = [];
  const fetchImpl = async (url) => {
    requests.push(new URL(url));
    const body = requests.length === 1
      ? '<a href="https://www.justwatch.com/uk/tv-series/solar-opposites">Solar Opposites (2020)</a>'
      : `<a href="${clickout.href.replace(/&/g, '&amp;')}">Disney Plus</a>`;
    return { ok: true, text: async () => body };
  };

  const links = await resolveJustWatchProviderLinks({ type: 'tv', title: 'Solar Opposites', region: 'GB', year: 2020, fetchImpl });

  assert.equal(requests[0].pathname, '/uk/search');
  assert.equal(requests[1].pathname, '/uk/tv-series/solar-opposites');
  assert.deepEqual(links, { 337: clickout.href });
});