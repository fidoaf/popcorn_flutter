const test = require('node:test');
const assert = require('node:assert/strict');
const { createPlayerServer } = require('../src/player/playerServer');

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