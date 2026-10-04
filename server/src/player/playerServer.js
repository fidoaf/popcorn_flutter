const http = require('node:http');
const { mediaFromQuery } = require('./mediaRequest');
const { renderPlayerPage } = require('./playerPage');
const { SubtitleRefStore } = require('./subtitleRefStore');
const { SourceRefStore } = require('./sourceRefStore');

function createPlayerServer({ initialMedia = null, providers, resourceProxy, subtitleRefs = new SubtitleRefStore(), sourceRefs = new SourceRefStore() }) {
  if (!providers || !resourceProxy) throw new TypeError('Player server requires providers and a resource proxy');

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
    if (request.method !== 'GET') {
      response.writeHead(405).end();
      return;
    }

    try {
      if (url.pathname === '/health') {
        response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end('ok');
      } else if (url.pathname === '/') {
        sendHtml(response, renderPlayerPage(initialMedia, { providers: providers.list() }));
      } else if (url.pathname === '/player') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        if (typeof provider.embedUrl === 'function' && typeof provider.extract !== 'function') {
          response.writeHead(302, { Location: provider.embedUrl(media).href, 'Cache-Control': 'no-store' }).end();
        } else {
          sendHtml(response, renderPlayerPage(media, { providers: providers.list(), showForm: false }));
        }
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

function sendJson(response, status, value) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
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