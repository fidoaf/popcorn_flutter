const http = require('node:http');
const test = require('node:test');
const assert = require('node:assert/strict');
const { ProviderRegistry } = require('../src/player/providerRegistry');
const { ResourceProxy } = require('../src/player/resourceProxy');

test('rewrites nested playlists and forwards byte ranges for media segments', async (t) => {
  const upstream = http.createServer((request, response) => {
    if (request.url === '/master.m3u8') {
      response.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      response.end('#EXTM3U\n/variant.m3u8\n');
    } else if (request.url === '/variant.m3u8') {
      response.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl' });
      response.end('#EXTM3U\n#EXTINF:4,\n/chunk.ts\n');
    } else if (request.url === '/chunk.ts') {
      assert.equal(request.headers.range, 'bytes=0-3');
      response.writeHead(206, { 'Content-Type': 'video/mp2t', 'Content-Range': 'bytes 0-3/4' });
      response.end('data');
    } else {
      response.writeHead(404).end();
    }
  });
  await new Promise((resolve) => upstream.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => upstream.close(resolve)));

  const origin = `http://127.0.0.1:${upstream.address().port}`;
  const providers = new ProviderRegistry([{ id: 'test', label: 'Test', origin }]);
  const resourceProxy = new ResourceProxy({ providers });
  const proxy = http.createServer(async (request, response) => {
    const path = new URL(request.url, 'http://localhost').pathname;
    if (path === '/master') await resourceProxy.serve(request, response, `${origin}/master.m3u8`, 'test');
    else if (path.startsWith('/resource/')) await resourceProxy.serveRegistered(request, response, path.slice('/resource/'.length));
    else response.writeHead(404).end();
  });
  await new Promise((resolve) => proxy.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => proxy.close(resolve)));
  const base = `http://127.0.0.1:${proxy.address().port}`;

  const master = await (await fetch(`${base}/master`)).text();
  assert.match(master, /^#EXTM3U/);
  const variantPath = master.split('\n').find((line) => line.startsWith('/resource/'));
  assert.ok(variantPath);

  const variant = await (await fetch(new URL(variantPath, base))).text();
  const segmentPath = variant.split('\n').find((line) => line.startsWith('/resource/'));
  assert.ok(segmentPath);

  const segment = await fetch(new URL(segmentPath, base), { headers: { Range: 'bytes=0-3' } });
  assert.equal(segment.status, 206);
  assert.equal(await segment.text(), 'data');
});

test('prefers the direct upstream exposed by a provider and falls back to the relay', async () => {
  const requests = [];
  const fetchImpl = async (url, { headers }) => {
    requests.push({ url, referer: headers.Referer });
    if (url === 'https://origin.test/ok.ts') return new Response('direct');
    if (url === 'https://origin.test/gone.ts') return new Response('gone', { status: 403 });
    return new Response('relayed');
  };
  const provider = {
    id: 'test',
    label: 'Test',
    origin: 'https://provider.test',
    directUpstream: (url) => {
      const target = new URL(url).searchParams.get('u');
      return target ? { url: target, referer: 'https://embed.test/' } : null;
    },
  };
  const resourceProxy = new ResourceProxy({ providers: new ProviderRegistry([provider]), fetchImpl });
  const serve = async (url) => {
    let body = '';
    const response = new (require('node:stream').Writable)({ write(chunk, _, done) { body += chunk; done(); } });
    response.writeHead = () => response;
    const finished = new Promise((resolve) => response.on('finish', resolve));
    await resourceProxy.serve({ url: '/', headers: {} }, response, url, 'test');
    await finished;
    return body;
  };

  assert.equal(await serve('https://relay.test/seg?u=https%3A%2F%2Forigin.test%2Fok.ts'), 'direct');
  assert.equal(await serve('https://relay.test/seg?u=https%3A%2F%2Forigin.test%2Fgone.ts'), 'relayed');
  assert.deepEqual(requests, [
    { url: 'https://origin.test/ok.ts', referer: 'https://embed.test/' },
    { url: 'https://origin.test/gone.ts', referer: 'https://embed.test/' },
    { url: 'https://relay.test/seg?u=https%3A%2F%2Forigin.test%2Fgone.ts', referer: 'https://provider.test/' },
  ]);
});