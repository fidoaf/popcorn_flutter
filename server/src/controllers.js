const fs = require('fs');
const { parseMediaParams, cacheKey } = require('./media');
const { sendJson, sendHtml } = require('./httpResponse');
const { playerPage, landingPage } = require('./views');

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
  }

  health(req, res) {
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
    const streamUrl = url.searchParams.get('url');
    if (!streamUrl) {
      sendJson(res, 400, { error: 'Missing url parameter' });
      return;
    }
    const token = this.auth.extractToken(req, url.searchParams);
    this.streamProxy.pipe(res, streamUrl, token);
  }

  async scrape(req, res, url) {
    if (!this.limiter.tryAcquire()) {
      sendJson(res, 429, { ok: false, error: 'Too many active scrapes; retry later.' });
      return;
    }
    try {
      const media = parseMediaParams(url.searchParams);
      const result = await this.scraper.extract(media);
      sendJson(res, 200, { ok: true, result });
    } finally {
      this.limiter.release();
    }
  }

  async proxyM3u8(req, res, url) {
    const media = parseMediaParams(url.searchParams);
    const key = cacheKey(media);
    let manifestUrl = this.streamCache.get(key);

    if (!manifestUrl) {
      manifestUrl = await this._resolveManifest(res, media, key);
      if (manifestUrl === undefined) return; // response already sent (busy/error)
    }

    if (!manifestUrl) {
      sendJson(res, 404, {
        error: 'Stream not found for ' + media.imdbId,
        media,
        source: this._sourceUrl(media),
        detail: 'Extraction completed but no HLS (.m3u8) manifest was detected on the embed page.',
      });
      return;
    }

    const token = this.auth.extractToken(req, url.searchParams);
    this.streamProxy.serveManifest(res, manifestUrl, token);
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
  async _resolveManifest(res, media, key) {
    if (!this.limiter.tryAcquire()) {
      sendJson(res, 503, { error: 'Too many active scrapes; retry later.' });
      return undefined;
    }
    try {
      const extraction = await this.scraper.extract(media);
      if (extraction.m3u8) {
        this.streamCache.set(key, extraction.m3u8);
      }
      return extraction.m3u8 || null;
    } catch (err) {
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
    }
  }

  player(req, res, url) {
    const media = parseMediaParams(url.searchParams);
    const token = this.auth.extractToken(req, url.searchParams);
    sendHtml(res, 200, playerPage(media, token));
  }

  landing(req, res) {
    sendHtml(res, 200, landingPage());
  }
}

module.exports = { Controllers };
