const test = require('node:test');
const assert = require('node:assert/strict');
const { LiveTvEpg, parseProgrammes } = require('../src/liveTvEpg');
const { createServer } = require('../server');
const { ProviderRegistry } = require('../src/player/providerRegistry');

const now = Date.parse('2026-10-15T18:00:00Z');
const channel = { id: 'Example.fr', name: 'Example TV', feed: 'Paris', country: 'FR' };
const directory = '<div data-xml="https://iptv-epg.org/files/epg-fr.xml" data-gz="https://iptv-epg.org/files/epg-fr.xml.gz"></div>';
const guideUrl = 'https://iptv-epg.org/files/epg-fr.xml';
const xml = `<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="Example.fr@Paris"><display-name>Example TV</display-name></channel>
  <programme channel="Example.fr@Paris" start="20261015193000 +0200" stop="20261015203000 +0200">
    <title>News &amp; Weather</title><desc>Evening news.</desc>
  </programme>
  <programme channel="Example.fr@Paris" start="20261015203000 +0200" stop="20261015213000 +0200"><title>Next show</title></programme>
  <programme channel="Example.fr@Paris" start="20261015163000 +0200" stop="20261015173000 +0200"><title>Past</title></programme>
  <programme channel="Other.fr" start="20261015193000 +0200" stop="20261015203000 +0200"><title>Wrong channel</title></programme>
  <programme channel="Example.fr@Paris" start="invalid" stop="20261015203000 +0200"><title>Invalid</title></programme>
</tv>`;

test('parses matching current/upcoming XMLTV programmes and timezone offsets', () => {
  const programmes = parseProgrammes(xml, channel, now);
  assert.deepEqual(programmes, [
    { title: 'News & Weather', description: 'Evening news.', start: '2026-10-15T17:30:00.000Z', end: '2026-10-15T18:30:00.000Z' },
    { title: 'Next show', description: '', start: '2026-10-15T18:30:00.000Z', end: '2026-10-15T19:30:00.000Z' },
  ]);
  assert.throws(() => parseProgrammes('<tv><broken></tv>', channel, now), /Invalid XMLTV/);
  assert.throws(() => parseProgrammes('<!DOCTYPE tv><tv/>', channel, now), /Invalid XMLTV/);
});

test('uses published IPTV-EPG country links and caches the directory and XML downloads', async () => {
  const requests = [];
  const epg = new LiveTvEpg({
    now: () => now,
    fetchImpl: async (url) => {
      requests.push(url);
      return new Response(url === 'https://iptv-epg.org/guides' ? directory : xml);
    },
  });
  assert.equal((await epg.getProgrammes(channel)).length, 2);
  assert.equal((await epg.getProgrammes(channel)).length, 2);
  assert.deepEqual(await epg.getProgrammes({ id: 'Missing.fr', name: 'Missing', country: 'FR' }), []);
  assert.deepEqual(await epg.getProgrammes({ id: 'Missing.us', country: 'US' }), []);
  assert.deepEqual(await epg.getProgrammes({ id: 'Missing', country: '' }), []);
  assert.deepEqual(requests, ['https://iptv-epg.org/guides', guideUrl]);
});

test('matches prefixed display names only when unique, preferring exact feed and channel IDs', () => {
  const prefixed = xml.replace('Example.fr@Paris', 'DifferentID.fr').replace('Example TV', 'FR - Example TV')
    .replaceAll('channel="Example.fr@Paris"', 'channel="DifferentID.fr"');
  assert.equal(parseProgrammes(prefixed, channel, now).length, 2);
  const ambiguous = prefixed.replace('</channel>', '</channel><channel id="Another.fr"><display-name>FR - Example TV</display-name></channel>');
  assert.deepEqual(parseProgrammes(ambiguous, channel, now), []);
  const feedAndBase = xml.replace('</tv>', `
    <channel id="Example.fr"><display-name>Example TV</display-name></channel>
    <programme channel="Example.fr" start="20261015193000 +0200" stop="20261015203000 +0200"><title>Base feed</title></programme>
    </tv>`);
  assert.equal(parseProgrammes(feedAndBase, channel, now).length, 2);
  assert.equal(parseProgrammes(feedAndBase, { ...channel, feed: '' }, now)[0].title, 'Base feed');
  assert.deepEqual(parseProgrammes(xml, { ...channel, id: 'OtherID.fr', name: 'Other name' }, now), []);
});

test('failed EPG downloads can be retried', async () => {
  let failed = true;
  const epg = new LiveTvEpg({
    now: () => now,
    fetchImpl: async (url) => url === 'https://iptv-epg.org/guides'
      ? new Response(directory)
      : failed ? new Response('', { status: 503 }) : new Response(xml),
  });
  await assert.rejects(epg.getProgrammes(channel), /EPG source request failed/);
  failed = false;
  assert.equal((await epg.getProgrammes(channel)).length, 2);
});

test('streaming XML handles split UTF-8 and retains the first 100 upcoming programmes', async () => {
  const guide = `<tv><channel id="Example.fr"><display-name>FR - Example TV</display-name></channel>${
    Array.from({ length: 105 }, (_, index) => {
      const start = new Date(now + index * 3600000).toISOString().replace(/[-:T]/g, '').slice(0, 14);
      const end = new Date(now + (index + 1) * 3600000).toISOString().replace(/[-:T]/g, '').slice(0, 14);
      return `<programme channel="Example.fr" start="${start} +0000" stop="${end} +0000"><title>Émission ${index}</title><desc><![CDATA[Actualités & météo]]></desc></programme>`;
    }).reverse().join('')
  }</tv>`;
  const bytes = new TextEncoder().encode(guide);
  const epg = new LiveTvEpg({
    now: () => now,
    fetchImpl: async (url) => url.endsWith('/guides') ? new Response(directory) : new Response(new ReadableStream({
      start(controller) {
        for (let index = 0; index < bytes.length; index += 7) controller.enqueue(bytes.slice(index, index + 7));
        controller.close();
      },
    })),
  });
  const rows = await epg.getProgrammes(channel);
  assert.equal(rows.length, 100);
  assert.equal(rows[0].title, 'Émission 0');
  assert.equal(rows[99].title, 'Émission 99');
  assert.equal(rows[0].description, 'Actualités & météo');
});

test('directory failures and malformed country XML are explicit and retryable', async () => {
  for (const initial of [
    { directoryResponse: () => new Response('', { status: 503 }), xml: xml },
    { directoryResponse: () => new Response('<html>No guide links</html>'), xml: xml },
    { directoryResponse: () => new Response(directory), xml: '<tv><broken></tv>' },
  ]) {
    let failed = true;
    const epg = new LiveTvEpg({
      now: () => now,
      fetchImpl: async (url) => url.endsWith('/guides')
        ? failed ? initial.directoryResponse() : new Response(directory)
        : new Response(failed ? initial.xml : xml),
    });
    await assert.rejects(epg.getProgrammes(channel), /EPG directory|guide directory|XMLTV/);
    failed = false;
    assert.equal((await epg.getProgrammes(channel)).length, 2);
  }
});

test('refreshes cached country XML and directory when their TTLs expire', async () => {
  let clock = now;
  const calls = [];
  const epg = new LiveTvEpg({
    now: () => clock,
    fetchImpl: async (url) => {
      calls.push(url);
      return new Response(url.endsWith('/guides') ? directory : xml);
    },
  });
  await Promise.all([epg.getProgrammes(channel), epg.getProgrammes(channel)]);
  assert.equal(calls.length, 2);
  clock += 16 * 60 * 1000;
  await epg.getProgrammes(channel);
  assert.equal(calls.length, 3);
  clock += 6 * 60 * 60 * 1000;
  await epg.getProgrammes(channel);
  assert.equal(calls.filter((url) => url.endsWith('/guides')).length, 2);
});

test('EPG endpoint is authenticated, returns JSON, and rejects unknown channels', async (t) => {
  const server = createServer(null, {
    providers: new ProviderRegistry([{ id: 'test', label: 'Test' }]),
    resourceProxy: {},
    apiTokens: new Set(['epg-test-token']),
    fetchImpl: async (url) => {
      if (url === guideUrl) return new Response(xml.replaceAll('20261015', '20991015'));
      if (url === 'https://iptv-epg.org/guides') return new Response(directory);
      return new Response(JSON.stringify(url.endsWith('/channels.json')
      ? [{ id: 'Example.fr', name: 'Example TV', country: 'FR' }]
      : url.endsWith('/streams.json')
        ? [{ channel: 'Example.fr', feed: 'Paris', url: 'https://example.com/live.m3u8' }]
        : []));
    },
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}/live-tv/epg`;
  assert.equal((await fetch(url + '?channel=Example.fr')).status, 401);
  const headers = { Authorization: 'Bearer epg-test-token' };
  const response = await fetch(url + '?channel=Example.fr', { headers });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).programmes[0].title, 'Past');
  assert.equal((await fetch(url + '?channel=Unknown', { headers })).status, 404);
});
