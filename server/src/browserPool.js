const puppeteer = require('puppeteer');

// Lazily launches and owns a single shared Chromium instance. Everything that
// needs a page depends on this abstraction rather than on Puppeteer's launch
// details, so browser configuration lives in exactly one place.
class BrowserPool {
  constructor({ chromePath } = {}) {
    this.chromePath = chromePath;
    this.browser = null;
    this.launchOptions = {
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--disable-extensions',
        '--disable-background-networking',
        '--disable-background-timer-throttling',
        '--disable-renderer-backgrounding',
        '--disable-backgrounding-occluded-windows',
        '--disable-ipc-flooding-protection',
        '--memory-pressure-off',
        '--js-flags=--max_old_space_size=256',
      ],
    };
    if (chromePath) {
      this.launchOptions.executablePath = chromePath;
    }
  }

  async acquire() {
    if (this.browser && this.browser.connected === false) {
      this.browser = null;
    }
    if (!this.browser) {
      this.browser = await puppeteer.launch(this.launchOptions);
      this.browser.on('disconnected', () => { this.browser = null; });
    }
    return this.browser;
  }

  async close() {
    if (this.browser) {
      await this.browser.close().catch(() => {});
      this.browser = null;
    }
  }
}

module.exports = { BrowserPool };
