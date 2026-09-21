const fs = require('fs');
const { parseMediaParams, cacheKey } = require('./media');
const { sendJson, sendHtml } = require('./httpResponse');
const { playerPage, landingPage } = require('./views');
const { createLogger } = require('./logger');

const moduleLog = createLogger('controllers');

// Request handlers. Each method owns one endpoint and delegates the real work to
// injected services, so this layer stays thin and free of business logic.
class Controllers {
  constructor({ config, auth, scraper, streamProxy, limiter, streamCache }) {
    this.config = config;
    this.auth = auth;
    this.scraper = scraper;
    this.streamProxy = streamProxy;
    this.limiter = limiter;
    this.streamCache = streamCache;
    this.inFlightManifestLoads = new Map();
  }

  health(req, res) {
    const log = req.log || moduleLog;
    log.debug('health check', { activeScrapes: this.limiter.activeCount });
    sendJson(res, 200, { ok: true, activeScrapes: this.limiter.activeCount });
  }

  favicon(req, res) {
    fs.readFile(this.config.faviconPath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end();
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'image/x-icon',
        'Cache-Control': 'public, max-age=86400',
      });
      res.end(data);
    });
  }

  proxyStream(req, res, url) {
    const log = req.log || moduleLog;
    const streamUrl = url.searchParams.get('url');
    if (!streamUrl) {
      log.warn('proxy-stream missing url parameter');
      sendJson(res, 400, { error: 'Missing url parameter' });
      return;
    }
    const token = this.auth.extractToken(req, url.searchParams);
    log.info('proxy-stream start', { streamUrl, hasToken: Boolean(token) });
    this.streamProxy.pipe(res, streamUrl, token, log);
  }

  async scrape(req, res, url) {
    const log = req.log || moduleLog;
    if (!this.limiter.tryAcquire()) {
      log.warn('scrape rejected: concurrency limit reached', {
        activeScrapes: this.limiter.activeCount,
      });
      sendJson(res, 429, { ok: false, error: 'Too many active scrapes; retry later.' });
      return;
    }
    const startedAt = Date.now();
    const media = parseMediaParams(url.searchParams);
    log.info('scrape acquired slot', { media, activeScrapes: this.limiter.activeCount });
    try {
      const result = await this.scraper.extract(media, log);
      log.info('scrape succeeded', {
        media,
        m3u8: result.m3u8,
        playing: result.playing,
        durationMs: Date.now() - startedAt,
      });
      sendJson(res, 200, { ok: true, result });
    } catch (err) {
      log.error('scrape failed', { media, durationMs: Date.now() - startedAt, error: err });
      throw err;
    } finally {
      this.limiter.release();
      log.debug('scrape released slot', { activeScrapes: this.limiter.activeCount });
    }
  }

  async proxyM3u8(req, res, url) {
    const log = req.log || moduleLog;
    const media = parseMediaParams(url.searchParams);
    const key = cacheKey(media);
    let manifestUrl = this.streamCache.get(key);

    if (manifestUrl) {
      log.info('proxy-m3u8 cache hit', { media, key, manifestUrl });
    } else {
      const inFlight = this.inFlightManifestLoads.get(key);
      if (inFlight) {
        log.info('proxy-m3u8 waiting on in-flight manifest resolution', { media, key });
        manifestUrl = await inFlight;
      } else {
        log.info('proxy-m3u8 cache miss; resolving manifest', { media, key });
        const pendingLoad = this._resolveManifest(res, media, key, log);
        this.inFlightManifestLoads.set(key, pendingLoad);
        try {
          manifestUrl = await pendingLoad;
        } finally {
          this.inFlightManifestLoads.delete(key);
        }
      }
      if (manifestUrl === undefined) return; // response already sent (busy/error)
    }

    if (!manifestUrl) {
      log.warn('proxy-m3u8 no manifest found', { media, source: this._sourceUrl(media) });
      sendJson(res, 404, {
        error: 'Stream not found for ' + media.imdbId,
        media,
        source: this._sourceUrl(media),
        detail: 'Extraction completed but no HLS (.m3u8) manifest was detected on the embed page.',
      });
      return;
    }

    const token = this.auth.extractToken(req, url.searchParams);
    log.info('proxy-m3u8 serving manifest', { manifestUrl, hasToken: Boolean(token) });
    this.streamProxy.serveManifest(res, manifestUrl, token, log);
  }

  // Best-effort resolution of the upstream embed URL for diagnostics.
  _sourceUrl(media) {
    try {
      return this.scraper.provider.buildSourceUrl(media);
    } catch (_) {
      return null;
    }
  }

  // Runs a scrape to discover and cache the manifest URL. Returns the URL (or
  // null when none found), or `undefined` after already writing a response.
  async _resolveManifest(res, media, key, log = moduleLog) {
    if (!this.limiter.tryAcquire()) {
      log.warn('manifest resolve rejected: concurrency limit reached', {
        activeScrapes: this.limiter.activeCount,
      });
      sendJson(res, 503, { error: 'Too many active scrapes; retry later.' });
      return undefined;
    }
    const startedAt = Date.now();
    log.info('manifest resolve acquired slot', { media, activeScrapes: this.limiter.activeCount });
    try {
      const extraction = await this.scraper.extract(media, log);
      if (extraction.m3u8) {
        this.streamCache.set(key, extraction.m3u8);
        log.info('manifest resolved and cached', {
          key,
          m3u8: extraction.m3u8,
          durationMs: Date.now() - startedAt,
        });
      } else {
        log.warn('manifest resolve produced no m3u8', {
          media,
          durationMs: Date.now() - startedAt,
        });
      }
      return extraction.m3u8 || null;
    } catch (err) {
      log.error('manifest resolve failed', {
        media,
        durationMs: Date.now() - startedAt,
        error: err,
      });
      sendJson(res, 500, {
        error: 'Extraction failed: ' + err.message,
        name: err.name,
        code: err.code,
        stage: 'extraction',
        media,
        source: this._sourceUrl(media),
        stack: (err.stack || '').split('\n').map((line) => line.trim()),
      });
      return undefined;
    } finally {
      this.limiter.release();
      log.debug('manifest resolve released slot', { activeScrapes: this.limiter.activeCount });
    }
  }

  player(req, res, url) {
    const log = req.log || moduleLog;
    const media = parseMediaParams(url.searchParams);
    const token = this.auth.extractToken(req, url.searchParams);
    log.info('serving player page', { media, hasToken: Boolean(token) });
    sendHtml(res, 200, playerPage(media, token));
  }

  landing(req, res) {
    const log = req.log || moduleLog;
    log.debug('serving landing page');
    sendHtml(res, 200, landingPage());
  }
}

module.exports = { Controllers };
