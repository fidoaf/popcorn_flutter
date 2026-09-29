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