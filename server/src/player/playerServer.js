const http = require('node:http');
const { mediaFromQuery } = require('./mediaRequest');
const { renderPlayerPage } = require('./playerPage');
const { SubtitleRefStore } = require('./subtitleRefStore');

function createPlayerServer({ initialMedia = null, providers, resourceProxy, subtitleRefs = new SubtitleRefStore() }) {
  if (!providers || !resourceProxy) throw new TypeError('Player server requires providers and a resource proxy');

  return http.createServer(async (request, response) => {
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
        sendHtml(response, renderPlayerPage(media, { providers: providers.list(), showForm: false }));
      } else if (url.pathname === '/favicon.ico') {
        response.writeHead(204).end();
      } else if (url.pathname === '/manifest') {
        const media = mediaFromQuery(url.searchParams, providers);
        const provider = providers.get(media.providerId);
        const stream = await provider.extract(media);
        await resourceProxy.serve(request, response, stream.url, provider.id);
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