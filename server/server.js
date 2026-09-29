#!/usr/bin/env node

const http = require('node:http');
const { randomUUID } = require('node:crypto');
const { Readable } = require('node:stream');

const ORIGIN = 'https://vidsrc.buzz';
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const HEADERS = { 'User-Agent': USER_AGENT, Referer: `${ORIGIN}/` };
const TIMEOUT_MS = 10000;

async function get(url) {
  const response = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(TIMEOUT_MS) });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText} from ${new URL(url).pathname}`);
  return response;
}

async function json(url) {
  return (await get(url)).json();
}

function playerConfig(html) {
  const match = html.match(/var Q\s*=\s*(\{.*?\});/s);
  if (!match) throw new Error('Player config Q not found in embed page');
  return JSON.parse(match[1]);
}

async function validate(candidate) {
  const url = new URL(candidate.url, ORIGIN).href;
  const response = await get(url);
  if (candidate.type !== 'mp4' && !(await response.text()).includes('#EXTM3U')) {
    throw new Error('Not an HLS playlist');
  }
  return { url, type: candidate.type || 'hls' };
}

async function extract(type, id, season = '0', episode = '0') {
  const path = type === 'movie' ? `movie/${id}` : `tv/${id}/${season}/${episode}`;
  const page = `${ORIGIN}/embed/${path}`;
  const config = playerConfig(await (await get(page)).text());
  const params = new URLSearchParams({
    type: String(config.type), id: String(config.id),
    s: String(config.s ?? 0), e: String(config.e ?? 0), t: String(config.t),
  });
  let servers = config.ssr?.servers || [];
  if (!servers.length) {
    const sources = await json(`${ORIGIN}/pl/api.php?a=sources&${params}`);
    servers = sources.servers || [];
  }
  const refs = servers.map((server) => server.ref).filter(Boolean);
  if (!refs.length) throw new Error('No servers available');

  const race = await json(`${ORIGIN}/pl/api.php?a=race&refs=${encodeURIComponent(refs.slice(0, 6).join(','))}`);
  for (const candidate of race.cands || []) {
    try {
      return { page, ...(await validate(candidate)) };
    } catch (_) {
      // Try the next candidate or mint a fresh URL for a server below.
    }
  }

  for (const ref of refs) {
    try {
      const candidate = await json(`${ORIGIN}/pl/api.php?a=play&ref=${encodeURIComponent(ref)}&t=${encodeURIComponent(config.t)}`);
      if (candidate.url) return { page, ...(await validate(candidate)) };
    } catch (_) {
      // A server can be unavailable even when listed on the embed page.
    }
  }
  throw new Error('No playable stream found');
}

async function fetchSubtitles(media) {
  const path = media.type === 'movie'
    ? `movie/${media.id}`
    : `tv/${media.id}/${media.season}/${media.episode}`;
  const page = `${ORIGIN}/embed/${path}`;
  const config = playerConfig(await (await get(page)).text());
  const query = new URLSearchParams({
    a: 'subs',
    type: String(config.type),
    id: String(config.id),
    s: String(config.s ?? 0),
    e: String(config.e ?? 0),
    t: String(config.t),
  });
  const result = await json(`${ORIGIN}/pl/api.php?${query}`);
  return Array.isArray(result.subs) ? result.subs : [];
}

function htmlEscape(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character]);
}

function playerHtml(initialMedia, { showForm = true } = {}) {
  const selectedType = initialMedia?.type || 'movie';
  const initialId = initialMedia?.id || '';
  const initialSeason = initialMedia?.season || '1';
  const initialEpisode = initialMedia?.episode || '1';
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>VidSrc Player</title>
  <style>
    html,body{margin:0;height:100%;background:#08090b;color:#f5f5f5;font-family:system-ui,sans-serif}
    main{min-height:100%;display:flex;flex-direction:column}
    header{padding:16px 20px;border-bottom:1px solid #292b30;display:flex;align-items:center;gap:20px;flex-wrap:wrap}
    h1{font-size:16px;margin:0 12px 0 0;white-space:nowrap}
    form{display:flex;align-items:end;gap:10px;flex-wrap:wrap}
    .field{display:grid;gap:5px;color:#aeb3bd;font-size:11px}
    input,form select{min-height:34px;box-sizing:border-box;padding:6px 9px;background:#17191e;color:#f5f5f5;border:1px solid #41444c;border-radius:4px;font:inherit;font-size:13px}
    input:focus,form select:focus,button:focus-visible{outline:2px solid #e50914;outline-offset:2px}
    #media-id{width:190px}
    .episode-field[hidden]{display:none}
    form button{min-height:34px;padding:0 14px;background:#e50914;border:0;border-radius:4px;color:white;font-weight:700}
    form button:hover{background:#ff2631}
    #now-playing{padding:10px 20px 0;color:#aeb3bd;font-size:13px}
    video{width:100%;flex:1;min-height:0;background:#000}
    footer{padding:8px 18px;min-height:36px;color:#aeb3bd;font-size:12px;display:flex;align-items:center;gap:12px}
    button{background:none;border:0;color:#f5f5f5;text-decoration:underline;cursor:pointer;font:inherit}
    label{display:flex;align-items:center;gap:8px;margin-left:auto}
    #subtitles{max-width:min(52vw,260px);padding:6px 8px;background:#17191e;color:#f5f5f5;border:1px solid #41444c;border-radius:4px}
    @media(max-width:640px){header{align-items:flex-start;flex-direction:column;gap:12px}form{width:100%}#media-id{width:min(190px,42vw)}.episode-field input{width:70px}#now-playing{padding-top:14px}video{min-height:45vh}}
  </style>
</head>
<body>
  <main>
    ${showForm ? `
    <header>
      <h1>VidSrc Player</h1>
      <form id="media-form">
        <label class="field" for="media-type">Type<select id="media-type"><option value="movie"${selectedType === 'movie' ? ' selected' : ''}>Movie</option><option value="tv"${selectedType === 'tv' ? ' selected' : ''}>TV show</option></select></label>
        <label class="field" for="media-id">IMDb or TMDB ID<input id="media-id" name="id" required pattern="(?:tt[0-9]+|[0-9]+)" placeholder="tt1375666 or 27205" value="${htmlEscape(initialId)}"></label>
        <label class="field episode-field" for="season"${selectedType === 'tv' ? '' : ' hidden'}>Season<input id="season" type="number" min="1" step="1" value="${htmlEscape(initialSeason)}"></label>
        <label class="field episode-field" for="episode"${selectedType === 'tv' ? '' : ' hidden'}>Episode<input id="episode" type="number" min="1" step="1" value="${htmlEscape(initialEpisode)}"></label>
        <button type="submit">Play</button>
      </form>
    </header>` : ''}
    <div id="now-playing" hidden></div>
    <video id="video" controls playsinline hidden></video>
    <footer><span id="status">Enter an IMDb or TMDB ID to start.</span> <button id="retry" hidden>Retry</button><label for="subtitles">Subtitles<select id="subtitles" disabled><option value="">Off</option></select></label></footer>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js"></script>
  <script>
    const video = document.getElementById('video');
    const status = document.getElementById('status');
    const retry = document.getElementById('retry');
    const subtitles = document.getElementById('subtitles');
    const form = document.getElementById('media-form');
    const typeInput = document.getElementById('media-type');
    const idInput = document.getElementById('media-id');
    const seasonInput = document.getElementById('season');
    const episodeInput = document.getElementById('episode');
    const episodeFields = document.querySelectorAll('.episode-field');
    const nowPlaying = document.getElementById('now-playing');
    const initialMedia = ${JSON.stringify(initialMedia)};
    let hls;
    let subtitleTrack;
    let selectedMedia;
    let requestGeneration = 0;
    function mediaQuery(media) {
      const query = new URLSearchParams({ type: media.type, id: media.id });
      if (media.type === 'tv') {
        query.set('season', media.season);
        query.set('episode', media.episode);
      }
      return query.toString();
    }
    function fail(message) {
      status.textContent = message;
      retry.hidden = false;
    }
    function clearSubtitleOptions() {
      if (subtitleTrack) { subtitleTrack.remove(); subtitleTrack = null; }
      subtitles.replaceChildren(new Option('Off', ''));
      subtitles.disabled = true;
    }
    async function autoplay(generation) {
      if (generation !== requestGeneration) return;
      try {
        await video.play();
        status.textContent = '';
      } catch (_) {
        video.muted = true;
        try {
          await video.play();
          status.textContent = 'Playing muted. Unmute to hear audio.';
        } catch (_) {
          status.textContent = 'Autoplay was blocked. Press play to start.';
        }
      }
    }
    function start(media) {
      const generation = ++requestGeneration;
      retry.hidden = true;
      status.textContent = 'Connecting to stream...';
      try {
        if (window.Hls && Hls.isSupported()) {
          if (hls) hls.destroy();
          hls = new Hls();
          hls.loadSource('/manifest?' + mediaQuery(media));
          hls.attachMedia(video);
          hls.on(Hls.Events.MANIFEST_PARSED, () => {
            autoplay(generation);
          });
          hls.on(Hls.Events.ERROR, (_, data) => {
            if (generation === requestGeneration && data.fatal) fail('Playback error: ' + data.details);
          });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
          video.src = '/manifest?' + mediaQuery(media);
          video.addEventListener('loadedmetadata', () => {
            autoplay(generation);
          }, { once: true });
        } else {
          throw new Error('This browser does not support HLS playback');
        }
        video.addEventListener('loadeddata', () => {
          if (generation === requestGeneration) status.textContent = '';
        }, { once: true });
      } catch (error) {
        fail('Unable to load stream: ' + error.message);
      }
    }
    video.addEventListener('error', () => fail('Video playback failed: ' + (video.error?.message || 'unsupported media')));
    async function loadSubtitles(media, generation) {
      try {
        const response = await fetch('/subtitles?' + mediaQuery(media));
        if (!response.ok) throw new Error('Subtitle list request failed');
        const tracks = await response.json();
        if (generation !== requestGeneration) return;
        for (const track of tracks) {
          const option = document.createElement('option');
          option.value = track.id;
          option.textContent = track.language && track.language !== track.label
            ? track.label + ' (' + track.language + ')'
            : track.label;
          subtitles.appendChild(option);
        }
        subtitles.disabled = false;
        if (!tracks.length) subtitles.title = 'No subtitles available';
      } catch (error) {
        subtitles.title = error.message;
      }
    }
    subtitles.addEventListener('change', () => {
      if (subtitleTrack) { subtitleTrack.remove(); subtitleTrack = null; }
      if (!subtitles.value) return;
      subtitleTrack = document.createElement('track');
      subtitleTrack.kind = 'subtitles';
      subtitleTrack.label = subtitles.selectedOptions[0].textContent;
      subtitleTrack.srclang = subtitles.selectedOptions[0].dataset.language || 'en';
      subtitleTrack.src = '/subtitle/' + encodeURIComponent(subtitles.value);
      subtitleTrack.default = true;
      video.appendChild(subtitleTrack);
      subtitleTrack.track.mode = 'showing';
      subtitleTrack.addEventListener('load', () => { subtitleTrack.track.mode = 'showing'; });
    });
    retry.addEventListener('click', () => {
      if (!selectedMedia) return;
      if (hls) { hls.destroy(); hls = null; }
      video.removeAttribute('src');
      video.load();
      start(selectedMedia);
    });
    function playMedia(media) {
      selectedMedia = media;
      nowPlaying.textContent = (media.type === 'movie' ? 'Movie ' : 'TV ') + media.id + (media.type === 'tv' ? ' · S' + media.season + ' E' + media.episode : '');
      nowPlaying.hidden = false;
      video.hidden = false;
      video.pause();
      video.removeAttribute('src');
      video.load();
      if (hls) { hls.destroy(); hls = null; }
      clearSubtitleOptions();
      start(media);
      const generation = requestGeneration;
      loadSubtitles(media, generation);
    }
    if (form) {
      typeInput.addEventListener('change', () => {
        const isTv = typeInput.value === 'tv';
        for (const field of episodeFields) field.hidden = !isTv;
        seasonInput.required = isTv;
        episodeInput.required = isTv;
      });
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        if (!form.reportValidity()) return;
        const media = { type: typeInput.value, id: idInput.value.trim() };
        if (media.type === 'tv') {
          media.season = seasonInput.value;
          media.episode = episodeInput.value;
        }
        playMedia(media);
      });
      typeInput.dispatchEvent(new Event('change'));
    }
    if (initialMedia) playMedia(initialMedia);
  </script>
</body>
</html>`;
}

function mediaFromQuery(params) {
  const type = (params.get('type') || 'movie').toLowerCase();
  const id = (params.get('id') || params.get('imdbId'))?.trim();
  if (!['movie', 'tv'].includes(type) || !/^(tt\d+|\d+)$/.test(id || '')) {
    const error = new Error('Provide a valid movie/TV type and IMDb or TMDB ID');
    error.statusCode = 400;
    throw error;
  }
  const media = { type, id };
  if (type === 'tv') {
    const season = params.get('season');
    const episode = params.get('episode');
    if (!/^[1-9]\d*$/.test(season || '') || !/^[1-9]\d*$/.test(episode || '')) {
      const error = new Error('TV shows require positive season and episode numbers');
      error.statusCode = 400;
      throw error;
    }
    media.season = season;
    media.episode = episode;
  } else {
    media.season = '0';
    media.episode = '0';
  }
  return media;
}

function createServer(media) {
  const resources = new Map();
  const subtitleRefs = new Map();
  const register = (url) => {
    for (const [key, entry] of resources) {
      if (entry.expires < Date.now()) resources.delete(key);
    }
    const key = randomUUID();
    resources.set(key, { url, expires: Date.now() + 30 * 60 * 1000 });
    return `/resource/${key}`;
  };

  function rewrite(body, base) {
    const local = (value) => register(new URL(value, base).href);
    return body.split('\n').map((line) => {
      if (!line.trim()) return line;
      if (!line.startsWith('#')) return local(line.trim());
      return line.replace(/URI="([^"]+)"/g, (_, url) => `URI="${local(url)}"`);
    }).join('\n');
  }

  async function fetchUpstream(request, url) {
    const headers = { ...HEADERS, ...(request.headers.range ? { Range: request.headers.range } : {}) };
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt++) {
      const controller = new AbortController();
      // Bound only the wait for headers; large segments may legitimately stream longer.
      const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
      try {
        const upstream = await fetch(url, { headers, signal: controller.signal });
        clearTimeout(timer);
        if (upstream.ok || upstream.status === 206 || upstream.status < 500) return upstream;
        lastError = new Error(`Upstream returned ${upstream.status}`);
        await upstream.body?.cancel();
      } catch (error) {
        clearTimeout(timer);
        lastError = error;
      }
      console.warn(`Upstream attempt ${attempt} failed for ${new URL(url).host}: ${lastError.message}`);
      await new Promise((resolve) => setTimeout(resolve, 300 * attempt));
    }
    throw lastError;
  }

  async function serveResource(request, response, url) {
    const upstream = await fetchUpstream(request, url);
    if (!upstream.ok && upstream.status !== 206) {
      console.warn(`Upstream ${upstream.status} for ${new URL(url).host}${new URL(url).pathname}`);
      await upstream.body?.cancel();
      response.writeHead(502).end(`Upstream returned ${upstream.status}`);
      return;
    }
    const contentType = upstream.headers.get('content-type') || '';
    if (/mpegurl/i.test(contentType) || /\.m3u8(?:\?|$)/i.test(upstream.url)) {
      const text = await upstream.text();
      if (!text.startsWith('#EXTM3U')) throw new Error('Invalid HLS playlist');
      response.writeHead(200, { 'Content-Type': 'application/vnd.apple.mpegurl', 'Cache-Control': 'no-store' });
      response.end(rewrite(text, upstream.url));
      return;
    }
    const headers = { 'Content-Type': contentType || 'application/octet-stream', 'Cache-Control': 'no-store' };
    if (upstream.headers.has('content-range')) headers['Content-Range'] = upstream.headers.get('content-range');
    if (upstream.headers.has('accept-ranges')) headers['Accept-Ranges'] = upstream.headers.get('accept-ranges');
    response.writeHead(upstream.status, headers);
    Readable.fromWeb(upstream.body).on('error', () => response.destroy()).pipe(response);
  }

  const server = http.createServer(async (request, response) => {
    const path = new URL(request.url, 'http://localhost').pathname;
    if (request.method !== 'GET') { response.writeHead(405).end(); return; }
    try {
      if (path === '/health') {
        response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end('ok');
      } else if (path === '/player') {
        const params = new URL(request.url, 'http://localhost').searchParams;
        const selectedMedia = mediaFromQuery(params);
        response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end(playerHtml(selectedMedia, { showForm: false }));
      } else if (path === '/') {
        response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end(playerHtml(media));
      } else if (path === '/favicon.ico') {
        response.writeHead(204).end();
      } else if (path === '/manifest') {
        const selectedMedia = mediaFromQuery(new URL(request.url, 'http://localhost').searchParams);
        const stream = await extract(selectedMedia.type, selectedMedia.id, selectedMedia.season, selectedMedia.episode);
        await serveResource(request, response, stream.url);
      } else if (path === '/subtitles') {
        const selectedMedia = mediaFromQuery(new URL(request.url, 'http://localhost').searchParams);
        const entries = await fetchSubtitles(selectedMedia);
        const tracks = [];
        for (const [id, entry] of subtitleRefs) {
          if (entry.expires < Date.now()) subtitleRefs.delete(id);
        }
        for (const entry of entries) {
          if (typeof entry.ref !== 'string' || typeof entry.label !== 'string') continue;
          const id = randomUUID();
          subtitleRefs.set(id, { ref: entry.ref, expires: Date.now() + 5 * 60 * 1000 });
          tracks.push({ id, label: entry.label, language: typeof entry.lang === 'string' ? entry.lang : '' });
        }
        response.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
        response.end(JSON.stringify(tracks));
      } else if (path.startsWith('/subtitle/')) {
        const id = path.slice('/subtitle/'.length);
        const entry = subtitleRefs.get(id);
        if (!entry || entry.expires < Date.now()) { response.writeHead(404).end('Subtitle expired; reload the page'); return; }
        const query = new URLSearchParams({ a: 'sub', ref: entry.ref });
        const upstream = await get(`${ORIGIN}/pl/api.php?${query}`);
        const body = await upstream.text();
        response.writeHead(200, {
          'Content-Type': upstream.headers.get('content-type') || 'text/vtt; charset=utf-8',
          'Cache-Control': 'no-store',
        });
        response.end(body);
      } else if (path.startsWith('/resource/')) {
        const key = path.slice('/resource/'.length);
        const entry = resources.get(key);
        if (!entry || entry.expires < Date.now()) { response.writeHead(404).end(); return; }
        await serveResource(request, response, entry.url);
      } else {
        response.writeHead(404).end();
      }
    } catch (error) {
      console.error(`Request ${path} failed: ${error.message}`);
      if (!response.headersSent) response.writeHead(error.statusCode || 502).end(error.statusCode === 400 ? error.message : 'Unable to load stream');
      else response.destroy();
    }
  });
  return server;
}

function main() {
  const [type, id, season, episode] = process.argv.slice(2);
  const invalidMedia = type && (
    !['movie', 'tv'].includes(type) ||
    !/^(tt\d+|\d+)$/.test(id || '') ||
    (type === 'tv' && (!/^[1-9]\d*$/.test(season || '') || !/^[1-9]\d*$/.test(episode || '')))
  );
  if (invalidMedia) {
    console.error('Usage: node vidsrc_extract.js [movie <imdb-or-tmdb-id> | tv <imdb-or-tmdb-id> <season> <episode>]');
    process.exitCode = 1;
    return;
  }
  const initialMedia = type ? { type, id, season: season || '1', episode: episode || '1' } : null;
  const port = Number(process.env.PORT || 3001);
  const server = createServer(initialMedia);
  let shuttingDown = false;

  function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[server] ${signal}; closing HTTP server`);
    const timeout = setTimeout(() => {
      console.error('[server] shutdown timed out; closing remaining connections');
      server.closeAllConnections();
    }, 10000);
    timeout.unref();
    server.close((error) => {
      clearTimeout(timeout);
      if (error) {
        console.error('[server] HTTP server close failed:', error);
        process.exitCode = 1;
      } else {
        console.log('[server] HTTP server closed');
      }
    });
  }

  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    console.error('[server] unhandled promise rejection:', reason);
    process.exitCode = 1;
    shutdown('unhandledRejection');
  });
  process.on('uncaughtException', (error) => {
    console.error('[server] uncaught exception:', error);
    process.exitCode = 1;
    shutdown('uncaughtException');
  });

  server.listen(port, '0.0.0.0', () => {
    console.log(`Player available at http://127.0.0.1:${port}/`);
  });
}

if (require.main === module) main();

module.exports = { extract, createServer };