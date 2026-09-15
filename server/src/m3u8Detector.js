// Watches a page's network traffic for an HLS manifest (.m3u8). It also
// neutralizes anti-devtools scripts and blocks `about:blank` navigations, since
// request interception must be handled in a single place once enabled.
class M3u8Detector {
  constructor(page) {
    this.page = page;
    this.found = null;
    this._resolve = null;
    this.promise = new Promise((resolve) => {
      this._resolve = resolve;
    });
  }

  _record(url) {
    if (this.found) return;
    this.found = url;
    this._resolve?.(url);
  }

  async attach() {
    await this.page.setRequestInterception(true);
    this.page.on('request', (req) => this._onRequest(req));
    this.page.on('response', (res) => this._onResponse(res));
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
        return req.respond({
          status: 200,
          contentType: 'application/javascript',
          body: '/* neutralized by puppeteer */',
        });
      }

      if (lower === 'about:blank' || lower.includes('about:blank')) {
        return req.abort();
      }

      req.continue();
    } catch (_) {
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
        this._record(url);
        return;
      }

      if (!this.found && contentType.includes('text')) {
        const text = await res.text().catch(() => null);
        if (text && text.includes('.m3u8')) {
          const match = text.match(/https?:\/\/[^\s"']+?\.m3u8/);
          if (match) this._record(match[0]);
        }
      }
    } catch (_) {}
  }

  waitFor(timeoutMs) {
    return Promise.race([
      this.promise,
      new Promise((resolve) => setTimeout(() => resolve(null), timeoutMs)),
    ]).catch(() => this.found || null);
  }
}

module.exports = { M3u8Detector };
