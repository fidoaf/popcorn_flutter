const { BrowserPool } = require('../browserPool');
const { blockNavigationHijacks, maskAutomation } = require('../pageHardening');
const { RedirectProvider } = require('./redirectProvider');

const DEFAULT_TIMEOUT_MS = 25000;
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

class CinesrcProvider extends RedirectProvider {
  constructor({ browserPool = new BrowserPool(), timeoutMs = DEFAULT_TIMEOUT_MS, ...definition }) {
    super(definition);
    this.browserPool = browserPool;
    this.timeoutMs = timeoutMs;
  }

  async listSources(media) {
    const playlist = await this._loadPlaylist(media);
    return {
      token: null,
      sources: parseVariants(playlist).map((variant, index) => ({
        ref: String(index),
        name: variant.label,
        lang: '',
        flag: '',
      })),
    };
  }

  async extract(media, selectedSource = null) {
    const playlist = await this._loadPlaylist(media);
    const variants = parseVariants(playlist);
    if (!selectedSource) return { url: playlist.url, type: 'hls' };

    const index = Number(selectedSource.ref);
    if (!Number.isInteger(index) || index < 0 || index >= variants.length) {
      const error = new Error('Selected CineSrc quality is no longer available; reload the player');
      error.statusCode = 400;
      throw error;
    }
    return { url: variants[index].url, type: 'hls' };
  }

  async close() {
    await this.browserPool.close();
  }

  async _loadPlaylist(media) {
    const browser = await this.browserPool.acquire();
    const page = await browser.newPage();
    let listener;
    let timer;
    try {
      await page.setJavaScriptEnabled(true);
      await page.setCacheEnabled(false);
      await page.setUserAgent(USER_AGENT);
      await page.setViewport({ width: 1280, height: 800 });
      await page.evaluateOnNewDocument(blockNavigationHijacks);
      await page.evaluateOnNewDocument(maskAutomation);

      let captured;
      let resolvePlaylist;
      let rejectPlaylist;
      const playlistPromise = new Promise((resolve, reject) => {
        resolvePlaylist = resolve;
        rejectPlaylist = reject;
      });
      let readingBody = false;
      listener = (response) => {
        if (captured || readingBody) return;
        let url;
        try {
          url = new URL(response.url());
        } catch (_) {
          return;
        }
        if (url.origin !== this.origin || !url.pathname.startsWith('/api/playlist/') || !url.pathname.toLowerCase().endsWith('.m3u8')) return;
        if (response.status() < 200 || response.status() >= 400) return;

        readingBody = true;
        response.text().then((body) => {
          readingBody = false;
          if (!body.trimStart().startsWith('#EXTM3U')) return;
          captured = { url: url.href, body };
          clearTimeout(timer);
          resolvePlaylist(captured);
        }).catch(() => {
          readingBody = false;
        });
      };
      page.on('response', listener);
      timer = setTimeout(() => rejectPlaylist(new Error('Timed out waiting for CineSrc playlist')), this.timeoutMs);

      const [, playlist] = await Promise.all([
        page.goto(this.embedUrl(media).href, { waitUntil: 'domcontentloaded', timeout: this.timeoutMs }),
        playlistPromise,
      ]);
      return playlist;
    } finally {
      clearTimeout(timer);
      if (listener) page.off('response', listener);
      await page.close().catch(() => {});
    }
  }
}

function parseVariants(playlist) {
  const lines = playlist.body.split(/\r?\n/).map((line) => line.trim());
  const variants = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
    const attributes = parseAttributes(line.slice(line.indexOf(':') + 1));
    let uriLine = index + 1;
    while (uriLine < lines.length && (!lines[uriLine] || lines[uriLine].startsWith('#'))) uriLine += 1;
    if (uriLine >= lines.length) continue;

    const url = new URL(lines[uriLine], playlist.url);
    if (!['http:', 'https:'].includes(url.protocol)) continue;
    const height = attributes.RESOLUTION?.split('x')[1];
    variants.push({
      url: url.href,
      label: attributes.NAME || (height ? `${height}p` : `Source ${variants.length + 1}`),
    });
    index = uriLine;
  }
  return variants.length ? variants : [{ url: playlist.url, label: 'Auto' }];
}

function parseAttributes(value) {
  const attributes = {};
  for (const match of value.matchAll(/([A-Z0-9-]+)=("[^"]*"|[^,]*)/g)) {
    attributes[match[1]] = match[2].replace(/^"|"$/g, '');
  }
  return attributes;
}

module.exports = { CinesrcProvider, parseVariants };