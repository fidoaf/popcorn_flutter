const http = require('node:http');
const { mediaFromQuery } = require('./mediaRequest');
const { renderPlayerPage } = require('./playerPage');
const { SubtitleRefStore } = require('./subtitleRefStore');
const { SourceRefStore } = require('./sourceRefStore');
const { resolveJustWatchProviderLinks } = require('./justWatchProviderLinks');
const { fetchIntroDb } = require('./introDb');
const { parseTokens } = require('../config');
const { PlayerAuth } = require('./playerAuth');
const { LiveTvCatalog } = require('../liveTvCatalog');
const { LiveTvEpg } = require('../liveTvEpg');
const { RadioCatalog } = require('../radioCatalog');

function createPlayerServer({ initialMedia = null, providers, resourceProxy, subtitleRefs = new SubtitleRefStore(), sourceRefs = new SourceRefStore(), fetchImpl = fetch, apiTokens = parseTokens(process.env.API_TOKENS || process.env.AUTH_TOKEN), auth = new PlayerAuth(apiTokens), liveTvCatalog = new LiveTvCatalog({ fetchImpl }), radioCatalog = new RadioCatalog({ fetchImpl }) }) {
  if (!providers || !resourceProxy) throw new TypeError('Player server requires providers and a resource proxy');
  const liveTvEpg = new LiveTvEpg({ fetchImpl });

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Authorization, Range');
    response.setHeader('Referrer-Policy', 'no-referrer');
    if (request.method === 'OPTIONS') {
      response.writeHead(204).end();
      return;
    }
    if (request.method !== 'GET') {
      response.writeHead(405).end();
      return;
    }
    if (!auth.authorize(request, url)) {
      sendJson(response, 401, { error: 'Unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
      return;
    }

    try {
      if (url.pathname === '/session') {
        sendJson(response, 200, { session: auth.createSession() });
      } else if (url.pathname === '/health') {
        response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end('ok');
      } else if (url.pathname === '/') {
        sendHtml(response, renderPlayerPage(initialMedia, { providers: providers.list(), session: auth.pageSession(url) }));
      } else if (url.pathname === '/providers') {
        sendJson(response, 200, { providers: providers.list(), defaultProvider: providers.defaultProviderId }, { 'Access-Control-Allow-Origin': '*' });
      } else if (url.pathname === '/radio') {
        const id = url.searchParams.get('station');
        const catalogue = id === null
          ? await radioCatalog.getCatalogue({ country: url.searchParams.get('country') || '' })
          : { stations: [await radioCatalog.getStation(id)].filter(Boolean) };
        sendJson(response, 200, catalogue);
      } else if (url.pathname === '/radio/play') {
        sendJson(response, 200, await radioCatalog.startPlayback(url.searchParams.get('station')));
      } else if (url.pathname === '/live-tv') {
        sendJson(response, 200, await liveTvCatalog.getCatalogue({
          country: url.searchParams.get('country') || '',
          channelId: url.searchParams.get('channel'),
          query: url.searchParams.get('q') || '',
        }));
      } else if (url.pathname === '/live-tv/epg') {
        const id = url.searchParams.get('channel');
        const channel = await liveTvCatalog.getChannel(id);
        if (!channel) {
          sendJson(response, 404, { error: 'channel_not_found' });
          return;
        }
        sendJson(response, 200, { programmes: await liveTvEpg.getProgrammes(channel) });
      } else if (url.pathname === '/player') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        const embedUrl = typeof provider.embedUrl === 'function' && typeof provider.extract !== 'function'
          ? provider.embedUrl(media).href : null;
        sendHtml(response, renderPlayerPage(media, { providers: providers.list(), showForm: false, embedUrl, session: auth.pageSession(url) }));
      } else if (url.pathname === '/watch-providers') {
        const links = await resolveJustWatchProviderLinks({
          type: url.searchParams.get('type'),
          title: url.searchParams.get('title'),
          year: url.searchParams.get('year'),
          region: url.searchParams.get('region'),
          fetchImpl,
        });
        sendJson(response, 200, links, { 'Access-Control-Allow-Origin': '*' });
      } else if (url.pathname === '/introdb') {
        sendJson(response, 200, await fetchIntroDb(url.searchParams, fetchImpl));
      } else if (url.pathname === '/favicon.ico') {
        response.writeHead(204).end();
      } else if (url.pathname === '/manifest') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        const sourceId = url.searchParams.get('source');
        const selectedSource = sourceId ? sourceRefs.get(sourceId, provider.id, media) : null;
        if (sourceId && !selectedSource) {
          const error = new Error('Selected source expired; reload the player');
          error.statusCode = 400;
          throw error;
        }
        const stream = await provider.extract(media, selectedSource);
        await resourceProxy.serve(request, response, stream.url, provider.id);
      } else if (url.pathname === '/sources') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        if (typeof provider.listSources !== 'function') {
          sendJson(response, 200, []);
          return;
        }
        const { token, sources } = await provider.listSources(media);
        const result = sources.map((source) => ({
          id: sourceRefs.add({ ref: source.ref, token }, provider.id, media),
          label: source.name,
          language: source.lang,
          flag: source.flag,
        }));
        sendJson(response, 200, result);
      } else if (url.pathname === '/nxsha/servers') {
        url.searchParams.set('provider', 'nxsha');
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        if (typeof provider.listServers !== 'function') {
          const error = new Error('Nxsha server lookup is unavailable');
          error.statusCode = 400;
          throw error;
        }
        sendJson(response, 200, await provider.listServers(media));
      } else if (url.pathname === '/subtitles') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        const tracks = await provider.listSubtitles(media);
        const result = tracks
          .filter((track) => typeof track.ref === 'string' && typeof track.label === 'string')
          .map((track) => ({
            id: subtitleRefs.add(track.ref, provider.id),
            label: track.label,
            language: typeof track.lang === 'string' ? track.lang : '',
          }));
        sendJson(response, 200, result);
      } else if (url.pathname.startsWith('/subtitle/')) {
        await serveSubtitle(response, url.pathname.slice('/subtitle/'.length), providers, subtitleRefs);
      } else if (url.pathname.startsWith('/resource/')) {
        await resourceProxy.serveRegistered(request, response, url.pathname.slice('/resource/'.length));
      } else {
        response.writeHead(404).end();
      }
    } catch (error) {
      console.error(`Request ${url.pathname} failed: ${error.message}`);
      if (!response.headersSent) {
        const status = error.statusCode || 502;
        if (url.pathname === '/radio' || url.pathname === '/radio/play') {
          sendJson(response, status, { error: status === 400 ? error.code || 'invalid_radio_station' : 'radio_unavailable' });
          return;
        }
        if (url.pathname === '/live-tv' || url.pathname === '/live-tv/epg') {
          sendJson(response, status, { error: 'live_tv_unavailable' });
          return;
        }
        if (url.pathname === '/watch-providers') {
          sendJson(response, status, { error: status === 400 ? error.message : 'Unable to load JustWatch provider links' });
          return;
        }
        response.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8' });
        response.end(status === 400 ? error.message : 'Unable to load stream');
      } else {
        response.destroy();
      }
    }
  });
  server.once('close', () => {
    for (const provider of providers.providers.values()) {
      if (typeof provider.close === 'function') {
        provider.close().catch((error) => console.warn(`Provider ${provider.id} close failed: ${error.message}`));
      }
    }
  });
  return server;
}

function sendHtml(response, html) {
  response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  response.end(html);
}

function sendJson(response, status, value, headers = {}) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
  response.end(JSON.stringify(value));
}

async function serveSubtitle(response, id, providers, subtitleRefs) {
  const entry = subtitleRefs.get(id);
  if (!entry) {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Subtitle expired; reload the page');
    return;
  }
  const body = await providers.get(entry.providerId).fetchSubtitle(entry.ref);
  response.writeHead(200, {
    'Content-Type': body.headers.get('content-type') || 'text/vtt; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  response.end(await body.text());
}

module.exports = { createPlayerServer };