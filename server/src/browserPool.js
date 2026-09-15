const puppeteer = require('puppeteer');
const { createLogger } = require('./logger');

const log = createLogger('browserPool');

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
      log.warn('cached browser is disconnected; discarding');
      this.browser = null;
    }
    if (!this.browser) {
      const startedAt = Date.now();
      log.info('launching Chromium', { executablePath: this.chromePath || 'bundled' });
      this.browser = await puppeteer.launch(this.launchOptions);
      log.info('Chromium launched', {
        durationMs: Date.now() - startedAt,
        pid: this.browser.process() ? this.browser.process().pid : null,
      });
      this.browser.on('disconnected', () => {
        log.warn('Chromium disconnected');
        this.browser = null;
      });
    } else {
      log.debug('reusing existing Chromium instance');
    }
    return this.browser;
  }

  async close() {
    if (this.browser) {
      log.info('closing Chromium');
      await this.browser.close().catch((err) => log.warn('error while closing Chromium', { error: err }));
      this.browser = null;
    }
  }
}

module.exports = { BrowserPool };
