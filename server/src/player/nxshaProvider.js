const crypto = require('node:crypto');
const { RedirectProvider } = require('./redirectProvider');
const { createLogger } = require('../logger');

const DEFAULT_TIMEOUT_MS = 10000;
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const PASSPHRASE = String.fromCharCode(83, 56, 120, 33, 74, 107, 52, 90, 80, 49, 117, 71, 56, 36, 109, 121);
const OPENSSL_HEADER = Buffer.from('Salted__');
const DEFAULT_LOGGER = createLogger('nxsha');

class NxshaProvider extends RedirectProvider {
  constructor({
    id = 'nxsha',
    label = 'Nxsha',
    scheme = 'https',
    host = 'web.nxsha.app',
    path = '/embed/{type}/{id}/{season}/{episode}',
    parameters = {},
    fetchImpl = globalThis.fetch,
    browserFetchImpl = null,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    logger = DEFAULT_LOGGER,
  } = {}) {
    super({ id, label, scheme, host, path, parameters });
    this.fetchImpl = fetchImpl;
    this.browserFetchImpl = browserFetchImpl;
    this.timeoutMs = timeoutMs;
    this.log = logger;
    this.browser = null;
    this.browserPagePromise = null;
    this.tmdbIdCache = new Map();
  }

  async listServers(media) {
    const lookupMedia = await this._resolveMedia(media);
    return this._listServers(lookupMedia, media);
  }

  async listSources(media) {
    const startedAt = Date.now();
    this.log.info('playable source listing started', mediaMeta(media));
    const sources = await this._listHlsSources(media);
    this.log.info('playable source listing completed', {
      ...mediaMeta(media),
      durationMs: Date.now() - startedAt,
      sourceCount: sources.length,
      sources: sources.map((source) => ({ label: source.name, host: safeHost(source.ref.url), language: source.lang, flag: source.flag })),
    });
    return { token: null, sources };
  }

  async listSubtitles(media) {
    const startedAt = Date.now();
    const lookupMedia = await this._resolveMedia(media);
    const url = this.subtitlesUrl(lookupMedia);
    this.log.info('subtitle catalog lookup started', {
      ...mediaMeta(media),
      resolvedTmdbId: lookupMedia.id,
      path: url.pathname,
    });
    const body = await this._request(url, 'json');
    const decoded = decodeData(body?._hash);
    if (!decoded || !Array.isArray(decoded.subtitles)) {
      this.log.warn('subtitle catalog response contained no decodable tracks', {
        ...mediaMeta(media),
        hasHash: typeof body?._hash === 'string',
        hashLength: typeof body?._hash === 'string' ? body._hash.length : 0,
      });
      return [];
    }
    const tracks = decoded.subtitles
      .filter((track) => typeof track?.uri === 'string' && track.uri)
      .map((track) => ({
        ref: track.uri,
        label: track.title || track.language || 'Subtitle',
        lang: track.language || '',
      }));
    this.log.info('subtitle catalog lookup completed', {
      ...mediaMeta(media),
      resolvedTmdbId: lookupMedia.id,
      durationMs: Date.now() - startedAt,
      returnedCount: decoded.subtitles.length,
      usableTrackCount: tracks.length,
      tracks: tracks.map((track) => ({ label: track.label, language: track.lang, host: safeHost(track.ref) })),
    });
    return tracks;
  }

  async fetchSubtitle(ref) {
    let url;
    try {
      url = new URL(ref);
    } catch (_) {
      throw new Error('Nxsha subtitle reference is not a valid URL');
    }
    if (url.protocol !== 'https:' || url.hostname !== 'dl.opensubtitles.org' || !url.pathname.includes('/download/src-api/')) {
      this.log.warn('subtitle download rejected as an unsupported URL', { host: url.host });
      throw new Error('Nxsha subtitle URL is not an approved OpenSubtitles download');
    }

    const startedAt = Date.now();
    this.log.info('subtitle download started', { host: url.host });
    let response;
    try {
      response = await this.fetchImpl(url, {
        headers: {
          Accept: 'text/vtt, application/x-subrip, text/plain, */*',
          'User-Agent': USER_AGENT,
          Referer: `${this.origin}/`,
        },
        signal: AbortSignal.timeout(this.timeoutMs),
      });
    } catch (error) {
      this.log.error('subtitle download request failed', {
        host: url.host,
        durationMs: Date.now() - startedAt,
        error: errorMeta(error),
      });
      throw error;
    }
    if (!response.ok) {
      this.log.warn('subtitle download returned an error status', {
        host: url.host,
        status: response.status,
        durationMs: Date.now() - startedAt,
      });
      throw new Error(`OpenSubtitles returned ${response.status} ${response.statusText}`);
    }
    const contentType = response.headers.get('content-type') || '';
    const text = await response.text();
    if (contentType.toLowerCase().includes('text/html')) {
      this.log.warn('subtitle download returned HTML instead of subtitle text', {
        host: url.host,
        bodyLength: text.length,
        durationMs: Date.now() - startedAt,
      });
      throw new Error('OpenSubtitles returned an HTML error page instead of a subtitle');
    }
    const webVtt = normalizeSubtitleText(text);
    this.log.info('subtitle download completed', {
      host: url.host,
      inputContentType: contentType,
      outputFormat: 'webvtt',
      bodyLength: webVtt.length,
      durationMs: Date.now() - startedAt,
    });
    return new Response(webVtt, {
      headers: { 'Content-Type': 'text/vtt; charset=utf-8' },
    });
  }

  async extract(media, selectedSource = null) {
    this.log.info('stream extraction started', { ...mediaMeta(media), selectedSource: Boolean(selectedSource) });
    if (selectedSource?.ref?.url) {
      this.log.info('selected HLS source accepted', {
        ...mediaMeta(media),
        host: safeHost(selectedSource.ref.url),
        label: selectedSource.name,
      });
      return { url: selectedSource.ref.url, type: 'hls' };
    }
    const [source] = await this._listHlsSources(media);
    if (!source) {
      this.log.warn('stream extraction found no direct HLS source', mediaMeta(media));
      throw new Error('No direct HLS sources available');
    }
    this.log.info('automatic HLS source selected', {
      ...mediaMeta(media),
      host: safeHost(source.ref.url),
      label: source.name,
      sourceLanguage: source.lang,
    });
    return { url: source.ref.url, type: 'hls' };
  }

  async close() {
    const browser = this.browser;
    this.log.info('browser cleanup started', { browserRunning: Boolean(browser) });
    this.browser = null;
    this.browserPagePromise = null;
    if (browser) await browser.close();
    this.log.info('browser cleanup completed');
  }

  sourcesUrl(media, scraper) {
    const url = new URL('/api/sources', this.origin);
    url.searchParams.set('q', encodeData({ ...buildServersPayload(media), ex_lang: Boolean(media.lang), provider: scraper }));
    return url;
  }

  subtitlesUrl(media) {
    const url = new URL('/api/subtitles', this.origin);
    url.searchParams.set('q', encodeData(buildServersPayload(media)));
    return url;
  }

  async _listHlsSources(media) {
    const lookupMedia = await this._resolveMedia(media);
    const allServers = await this._listServers(lookupMedia, media);
    const excluded = { missingScraper: 0, webUnsupported: 0, cookieRequired: 0 };
    const servers = allServers.filter((server) => {
      if (!server?.scraper) { excluded.missingScraper += 1; return false; }
      if (server.web_support === false) { excluded.webUnsupported += 1; return false; }
      if (server.scraper === 'showbox-online') { excluded.cookieRequired += 1; return false; }
      return true;
    });
    this.log.info('scraper fan-out started', {
      ...mediaMeta(media),
      catalogCount: allServers.length,
      eligibleCount: servers.length,
      excluded,
    });
    const sourcesByServer = await Promise.all(servers.map(async (server) => {
      const startedAt = Date.now();
      this.log.debug('scraper source lookup started', { ...mediaMeta(media), scraper: server.scraper, server: server.name });
      try {
        const url = this.sourcesUrl(lookupMedia, server.scraper);
        const body = await this._request(url, 'json');
        const decoded = decodeData(body?._hash);
        if (!decoded || !Array.isArray(decoded.sources)) {
          this.log.warn('scraper returned no decodable source list', {
            ...mediaMeta(media),
            scraper: server.scraper,
            hasHash: typeof body?._hash === 'string',
            hashLength: typeof body?._hash === 'string' ? body._hash.length : 0,
            durationMs: Date.now() - startedAt,
          });
          return [];
        }
        let rejectedCount = 0;
        const sources = decoded.sources.map((source) => {
          const normalized = normalizeHlsSource(source, server);
          if (!normalized) {
            rejectedCount += 1;
            this.log.debug('source rejected by HLS filter', {
              ...mediaMeta(media),
              scraper: server.scraper,
              type: source?.type || '',
              isEmbed: Boolean(source?.isEmbed),
              hasUrl: typeof source?.url === 'string',
              urlExtension: safeExtension(source?.url),
            });
          }
          return normalized;
        }).filter(Boolean);
        this.log.info('scraper source lookup completed', {
          ...mediaMeta(media),
          scraper: server.scraper,
          server: server.name,
          returnedCount: decoded.sources.length,
          directHlsCount: sources.length,
          rejectedCount,
          durationMs: Date.now() - startedAt,
          sourceHosts: sources.map((source) => safeHost(source.ref.url)),
        });
        return sources;
      } catch (error) {
        this.log.warn('scraper source lookup failed', {
          ...mediaMeta(media),
          scraper: server.scraper,
          server: server.name,
          durationMs: Date.now() - startedAt,
          error: errorMeta(error),
        });
        return [];
      }
    }));
    const seenUrls = new Set();
    let duplicateCount = 0;
    const sources = sourcesByServer.flat().filter((source) => {
      if (seenUrls.has(source.ref.url)) { duplicateCount += 1; return false; }
      seenUrls.add(source.ref.url);
      return true;
    });
    this.log.info('scraper fan-out completed', {
      ...mediaMeta(media),
      eligibleCount: servers.length,
      uniqueHlsCount: sources.length,
      duplicateCount,
    });
    return sources;
  }

  async _listServers(lookupMedia, originalMedia = lookupMedia) {
    const startedAt = Date.now();
    const url = this.serversUrl(lookupMedia);
    this.log.info('server catalog lookup started', {
      ...mediaMeta(originalMedia),
      resolvedTmdbId: lookupMedia.id,
      path: url.pathname,
    });
    const body = await this._request(url, 'json');
    const decoded = decodeData(body?._hash);
    if (!decoded) {
      this.log.warn('server catalog response could not be decoded', {
        ...mediaMeta(originalMedia),
        hasHash: typeof body?._hash === 'string',
        hashLength: typeof body?._hash === 'string' ? body._hash.length : 0,
      });
      return [];
    }
    const servers = Array.isArray(decoded.servers) ? decoded.servers : [];
    this.log.info('server catalog lookup completed', {
      ...mediaMeta(originalMedia),
      resolvedTmdbId: lookupMedia.id,
      durationMs: Date.now() - startedAt,
      serverCount: servers.length,
      webSupportedCount: servers.filter((server) => server?.web_support !== false).length,
      serverPreview: servers.slice(0, 5).map((server) => ({ name: server?.name, scraper: server?.scraper, webSupport: server?.web_support })),
    });
    return servers;
  }

  async _resolveMedia(media) {
    const id = String(media.id || '');
    if (!/^tt\d+$/.test(id)) return media;
    const cachedTmdbId = this.tmdbIdCache.get(id);
    if (cachedTmdbId) {
      this.log.debug('IMDb-to-TMDB mapping cache hit', { imdbId: id, tmdbId: cachedTmdbId });
      return { ...media, id: cachedTmdbId, imdbId: id };
    }

    const startedAt = Date.now();
    const embedUrl = this.embedUrl(media);
    this.log.info('IMDb-to-TMDB resolution started', { imdbId: id, path: embedUrl.pathname });
    const html = await this._request(embedUrl, 'text');
    const match = html.match(/\\?"tmdbId\\?"\s*:\s*(\d+)/);
    if (!match) {
      this.log.warn('IMDb-to-TMDB resolution found no mapping', {
        imdbId: id,
        durationMs: Date.now() - startedAt,
        responseLength: html.length,
      });
      throw new Error(`Nxsha could not resolve IMDb ID ${id} to a TMDB ID`);
    }
    const tmdbId = match[1];
    this.tmdbIdCache.set(id, tmdbId);
    this.log.info('IMDb-to-TMDB resolution completed', {
      imdbId: id,
      tmdbId,
      durationMs: Date.now() - startedAt,
    });
    return { ...media, id: tmdbId, imdbId: id };
  }

  async _request(url, responseType) {
    const startedAt = Date.now();
    const requestMeta = { origin: url.origin, path: url.pathname, method: 'GET', responseType };
    this.log.debug('API request started', requestMeta);
    const options = {
      headers: {
        Accept: responseType === 'json' ? 'application/json' : 'text/html',
        'User-Agent': USER_AGENT,
        Referer: `${this.origin}/`,
      },
      signal: AbortSignal.timeout(this.timeoutMs),
    };
    let response;
    let nodeError;
    try {
      response = await this.fetchImpl(url, options);
      if (response.ok) {
        const body = await readResponse(response, responseType);
        this.log.info('API request completed', {
          ...requestMeta,
          transport: 'node',
          status: response.status,
          durationMs: Date.now() - startedAt,
        });
        return body;
      }
      await response.body?.cancel();
      nodeError = new Error(`${response.status} ${response.statusText} from ${url.pathname}`);
    } catch (error) {
      nodeError = error;
    }

    this.log.warn('Node API request failed; trying Chromium', {
      ...requestMeta,
      durationMs: Date.now() - startedAt,
      error: errorMeta(nodeError),
    });
    const browserStartedAt = Date.now();
    try {
      response = await (this.browserFetchImpl || this._browserFetch.bind(this))(url, options);
    } catch (browserError) {
      this.log.error('Chromium API request failed', {
        ...requestMeta,
        durationMs: Date.now() - browserStartedAt,
        error: errorMeta(browserError),
      });
      throw new AggregateError([nodeError, browserError], `Nxsha API request failed: ${browserError.message}`);
    }
    if (!response.ok) {
      const error = new Error(`${response.status} ${response.statusText} from ${url.pathname}`);
      this.log.error('Chromium API request returned an error status', {
        ...requestMeta,
        status: response.status,
        durationMs: Date.now() - browserStartedAt,
      });
      throw error;
    }
    const body = await readResponse(response, responseType);
    this.log.info('API request completed', {
      ...requestMeta,
      transport: 'chromium',
      status: response.status,
      durationMs: Date.now() - browserStartedAt,
    });
    return body;
  }

  async _browserFetch(url, options) {
    const page = await this._getBrowserPage();
    const startedAt = Date.now();
    this.log.debug('Chromium fetch started', { origin: url.origin, path: url.pathname });
    const result = await page.evaluate(async ({ target, headers, timeoutMs }) => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await fetch(target, { headers, signal: controller.signal, cache: 'no-store' });
        return {
          status: response.status,
          statusText: response.statusText,
          headers: [...response.headers.entries()],
          body: await response.text(),
        };
      } finally {
        clearTimeout(timeout);
      }
    }, { target: String(url), headers: options.headers, timeoutMs: this.timeoutMs });
    this.log.debug('Chromium fetch received response', {
      origin: url.origin,
      path: url.pathname,
      status: result.status,
      bodyLength: result.body.length,
      durationMs: Date.now() - startedAt,
    });
    return new Response(result.body, {
      status: result.status,
      statusText: result.statusText,
      headers: result.headers,
    });
  }

  async _getBrowserPage() {
    if (!this.browserPagePromise) {
      const startedAt = Date.now();
      this.log.info('launching Chromium for Nxsha API transport', { origin: this.origin });
      this.browserPagePromise = (async () => {
        const puppeteer = require('puppeteer');
        const browser = await puppeteer.launch({
          headless: 'new',
          args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
        });
        this.browser = browser;
        browser.once('disconnected', () => {
          this.browser = null;
          this.browserPagePromise = null;
        });
        const page = await browser.newPage();
        this.log.debug('Chromium page created; establishing same-origin context', { path: '/favicon.ico' });
        await page.goto(new URL('/favicon.ico', this.origin).href, {
          waitUntil: 'domcontentloaded',
          timeout: this.timeoutMs,
        });
        this.log.info('Chromium Nxsha context ready', { durationMs: Date.now() - startedAt });
        return page;
      })().catch((error) => {
        this.log.error('Chromium Nxsha context initialization failed', {
          durationMs: Date.now() - startedAt,
          error: errorMeta(error),
        });
        this.browserPagePromise = null;
        throw error;
      });
    }
    return this.browserPagePromise;
  }

  serversUrl(media) {
    const url = new URL('/api/servers', this.origin);
    url.searchParams.set('q', encodeData(buildServersPayload(media)));
    return url;
  }
}

function buildServersPayload(media) {
  const id = String(media.id || '');
  return {
    tmdbId: /^\d+$/.test(id) ? Number(id) : '',
    imdb_id: media.imdbId || (/^tt\d+$/.test(id) ? id : ''),
    type: String(media.type),
    season: media.type === 'tv' ? Number(media.season) : 1,
    episode: media.type === 'tv' ? Number(media.episode) : 1,
  };
}

async function readResponse(response, responseType) {
  return responseType === 'json' ? response.json() : response.text();
}

function mediaMeta(media) {
  return {
    type: media.type,
    id: media.id,
    ...(media.type === 'tv' ? { season: media.season, episode: media.episode } : {}),
    language: media.lang || 'en',
  };
}

function safeHost(value) {
  try { return new URL(value).host; } catch (_) { return ''; }
}

function safeExtension(value) {
  try { return new URL(value).pathname.split('/').at(-1).split('.').at(-1).toLowerCase().slice(0, 8); } catch (_) { return ''; }
}

function errorMeta(error) {
  return {
    name: error?.name || 'Error',
    code: error?.code,
    message: String(error?.message || error || 'Unknown error').replace(/https?:\/\/\S+/g, '<url>'),
  };
}

function normalizeHlsSource(source, server) {
  if (!source || source.isEmbed === true || typeof source.url !== 'string') return null;
  let url;
  try {
    url = new URL(source.url);
  } catch (_) {
    return null;
  }
  if (!['http:', 'https:'].includes(url.protocol)) return null;
  const sourceType = String(source.type || '').toLowerCase();
  if (!url.pathname.toLowerCase().endsWith('.m3u8') && !sourceType.includes('hls') && !sourceType.includes('m3u8')) return null;

  const sourceName = source.name || source.title || source.quality || 'HLS';
  const label = [server.name, sourceName, source.quality]
    .filter((value, index, values) => value && values.indexOf(value) === index)
    .join(' · ');
  return {
    ref: { url: url.href },
    name: label || 'HLS source',
    lang: source.language || source.lang || '',
    flag: source.flag || server.flag || '',
  };
}

function normalizeSubtitleText(value) {
  const text = String(value || '').replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').trim();
  if (/^WEBVTT(?:\s|$)/i.test(text)) return `${text}\n`;
  if (!/^\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}/m.test(text)) {
    throw new Error('OpenSubtitles response is not valid SRT or WebVTT');
  }
  const cues = text
    .replace(/^\d+\s*$/gm, '')
    .replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2')
    .trim();
  return `WEBVTT\n\n${cues}\n`;
}

function encodeData(value) {
  const request = {
    ...value,
    _req_ts: Date.now(),
    _req_salt: Math.random().toString(36).substring(2, 12),
  };
  const salt = crypto.randomBytes(8);
  const { key, iv } = deriveKeyAndIv(salt);
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(request)), cipher.final()]);
  return Buffer.concat([OPENSSL_HEADER, salt, ciphertext]).toString('base64url');
}

function decodeData(value) {
  if (typeof value !== 'string' || !value) return null;
  try {
    const encrypted = Buffer.from(value.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
    if (!encrypted.subarray(0, OPENSSL_HEADER.length).equals(OPENSSL_HEADER)) return null;
    const salt = encrypted.subarray(8, 16);
    const { key, iv } = deriveKeyAndIv(salt);
    const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
    const plaintext = Buffer.concat([decipher.update(encrypted.subarray(16)), decipher.final()]).toString('utf8');
    const decoded = JSON.parse(plaintext);
    delete decoded._req_ts;
    delete decoded._req_salt;
    return decoded;
  } catch (_) {
    return null;
  }
}

function deriveKeyAndIv(salt) {
  const passphrase = Buffer.from(PASSPHRASE, 'utf8');
  let previous = Buffer.alloc(0);
  let material = Buffer.alloc(0);
  while (material.length < 48) {
    previous = crypto.createHash('md5').update(Buffer.concat([previous, passphrase, salt])).digest();
    material = Buffer.concat([material, previous]);
  }
  return { key: material.subarray(0, 32), iv: material.subarray(32, 48) };
}

module.exports = { NxshaProvider, buildServersPayload, decodeData, encodeData };