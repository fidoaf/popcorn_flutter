// Watches a page's network traffic for an HLS manifest (.m3u8). It also
// neutralizes anti-devtools scripts and blocks `about:blank` navigations, since
// request interception must be handled in a single place once enabled.
const { createLogger } = require('./logger');

class M3u8Detector {
  constructor(page, log = createLogger('scraper:detector')) {
    this.page = page;
    this.log = log;
    this.found = null;
    this._resolve = null;
    this.promise = new Promise((resolve) => {
      this._resolve = resolve;
    });
  }

  _record(url) {
    if (this.found) return;
    this.found = url;
    this.log.info('m3u8 detected', { url });
    this._resolve?.(url);
  }

  async attach() {
    await this.page.setRequestInterception(true);
    this.page.on('request', (req) => this._onRequest(req));
    this.page.on('response', (res) => this._onResponse(res));
    this.log.debug('request interception enabled');
  }

  _onRequest(req) {
    try {
      const url = req.url();
      const lower = url.toLowerCase();
      const resourceType = req.resourceType();

      if (!this.found && lower.includes('.m3u8')) {
        this._record(url);
      }

      const suspect =
        resourceType === 'script' &&
        (lower.includes('devtool') ||
          lower.includes('anti') ||
          lower.includes('block') ||
          lower.includes('detect') ||
          lower.includes('devtools'));

      if (suspect) {
        this.log.debug('neutralizing suspect script', { url });
        return req.respond({
          status: 200,
          contentType: 'application/javascript',
          body: '/* neutralized by puppeteer */',
        });
      }

      if (lower === 'about:blank' || lower.includes('about:blank')) {
        this.log.debug('aborting about:blank navigation', { url });
        return req.abort();
      }

      req.continue();
    } catch (err) {
      this.log.warn('request handler error', { error: err });
      try {
        req.continue();
      } catch (_) {}
    }
  }

  async _onResponse(res) {
    try {
      const url = res.url();
      const lower = url.toLowerCase();

      if (!this.found && lower.includes('.m3u8')) {
        this._record(url);
        return;
      }

      const headers = res.headers ? res.headers() : {};
      const contentType = (headers['content-type'] || headers['Content-Type'] || '').toLowerCase();

      if (
        !this.found &&
        (contentType.includes('application/vnd.apple.mpegurl') ||
          contentType.includes('vnd.apple.mpegurl') ||
          contentType.includes('application/x-mpegurl') ||
          contentType.includes('mpegurl'))
      ) {
        this.log.debug('m3u8 detected via content-type', { url, contentType });
        this._record(url);
        return;
      }

      if (!this.found && contentType.includes('text')) {
        const text = await res.text().catch(() => null);
        if (text && text.includes('.m3u8')) {
          const match = text.match(/https?:\/\/[^\s"']+?\.m3u8/);
          if (match) {
            this.log.debug('m3u8 found embedded in text response', { sourceUrl: url });
            this._record(match[0]);
          }
        }
      }
    } catch (err) {
      this.log.warn('response handler error', { error: err });
    }
  }

  waitFor(timeoutMs) {
    return Promise.race([
      this.promise,
      new Promise((resolve) => setTimeout(() => resolve(null), timeoutMs)),
    ]).catch(() => this.found || null);
  }
}

module.exports = { M3u8Detector };
