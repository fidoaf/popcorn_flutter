const { M3u8Detector } = require('./m3u8Detector');
const { blockNavigationHijacks, maskAutomation } = require('./pageHardening');
const { createLogger } = require('./logger');

const moduleLog = createLogger('scraper');

// Attempt to start playback in a document context and report the resolved
// source. Serialized into the page, so it must be fully self-contained.
async function playInDocument() {
  try {
    const tryPlay = async (video) => {
      try {
        video.muted = false;
        await video.play().catch(() => {});
        return video.currentSrc || video.src || null;
      } catch (_) {
        return null;
      }
    };

    const video = document.querySelector('video');
    if (video) return await tryPlay(video);

    const buttonSelectors = [
      '.play',
      '.play-button',
      '.vjs-play-control',
      '.jw-icon-play',
      'button[aria-label="Play"]',
      'button[title="Play"]',
    ];

    for (const selector of buttonSelectors) {
      const button = document.querySelector(selector);
      if (button) {
        button.click();
        return null;
      }
    }

    return null;
  } catch (_) {
    return null;
  }
}

async function playInFrame() {
  try {
    const video = document.querySelector('video');
    if (video) {
      video.muted = false;
      await video.play().catch(() => {});
      return video.currentSrc || video.src || null;
    }

    const button = document.querySelector('.play, .play-button, button[aria-label="Play"]');
    if (button) {
      button.click();
      return null;
    }

    return null;
  } catch (_) {
    return null;
  }
}

// Drives a headless browser to load an embed page and detect its HLS stream.
// Depends only on injected collaborators (browser pool + source provider),
// which keeps the scraping policy independent of infrastructure details.
class StreamScraper {
  constructor({ browserPool, provider, config }) {
    this.browserPool = browserPool;
    this.provider = provider;
    this.userAgent = config.userAgent;
    this.navigationTimeoutMs = config.scrapeTimeoutMs;
    this.m3u8WaitMs = config.m3u8WaitMs;
    this.hardDeadlineMs = config.scrapeHardDeadlineMs;
  }

  // Guarantees the returned promise settles within a bounded time. Puppeteer's
  // per-op timeouts don't cover every call (newPage/evaluate can hang on a
  // memory-starved host), and a hang here would never release the concurrency
  // slot the caller holds, permanently jamming the server with 429s.
  async extract(media, log = moduleLog) {
    let timer;
    const deadline = new Promise((_, reject) => {
      timer = setTimeout(
        () => reject(new Error('Scrape exceeded hard deadline')),
        this.hardDeadlineMs,
      );
    });
    log.debug('extract start', { media, hardDeadlineMs: this.hardDeadlineMs });
    try {
      return await Promise.race([this._extractOnce(media, log), deadline]);
    } catch (err) {
      if (err.message === 'Scrape exceeded hard deadline') {
        log.error('extract hit hard deadline; recycling browser', {
          media,
          hardDeadlineMs: this.hardDeadlineMs,
        });
        // Recycle the browser: a wedged Chromium would hang every future scrape.
        await this.browserPool.close().catch(() => {});
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }

  async _extractOnce(media, log = moduleLog) {
    const sourceUrl = this.provider.buildSourceUrl(media);
    log.info('acquiring browser', { sourceUrl });
    const browser = await this.browserPool.acquire();
    const page = await browser.newPage();
    log.debug('new page created');

    try {
      await this._preparePage(page);
      log.debug('page prepared');
      const detector = new M3u8Detector(page, log.child('detector'));
      await detector.attach();
      log.debug('m3u8 detector attached');

      log.info('navigating to source', { sourceUrl, timeoutMs: this.navigationTimeoutMs });
      await page.goto(sourceUrl, { waitUntil: 'networkidle2', timeout: this.navigationTimeoutMs });
      log.debug('navigation settled');

      const playingSrc = await this._attemptPlayback(page, log);
      log.info('playback attempt done', { playing: Boolean(playingSrc), src: playingSrc });

      log.debug('waiting for m3u8', { m3u8WaitMs: this.m3u8WaitMs });
      const m3u8 = await detector.waitFor(this.m3u8WaitMs);
      const resolvedM3u8 = m3u8 || detector.found;
      log.info('m3u8 wait complete', { resolvedM3u8 });

      if (resolvedM3u8) {
        await this._openHlsPreview(browser, resolvedM3u8, log);
      }

      return {
        imdbId: media.imdbId,
        type: media.type,
        season: media.season,
        episode: media.episode,
        page: sourceUrl,
        playing: !!playingSrc,
        src: playingSrc,
        m3u8: resolvedM3u8,
      };
    } finally {
      await page.close().catch(() => {});
      log.debug('page closed');
    }
  }

  async _preparePage(page) {
    await page.setJavaScriptEnabled(true);
    await page.setCacheEnabled(false);
    await page.setUserAgent(this.userAgent);
    await page.setViewport({ width: 1280, height: 800 });
    await page.evaluateOnNewDocument(blockNavigationHijacks);
    await page.evaluateOnNewDocument(maskAutomation);
    page.on('dialog', async (dialog) => {
      await dialog.dismiss().catch(() => {});
    });
    page.on('popup', async (popup) => {
      if (popup) await popup.close().catch(() => {});
    });
  }

  async _attemptPlayback(page, log = moduleLog) {
    let playingSrc = await page.evaluate(playInDocument);
    if (playingSrc) {
      log.debug('playback started in main document', { src: playingSrc });
      return playingSrc;
    }

    const frames = page.frames();
    log.debug('main document did not yield playback; scanning frames', { frameCount: frames.length });
    for (const frame of frames) {
      const frameSrc = await frame.evaluate(playInFrame).catch(() => null);
      if (frameSrc) {
        log.debug('playback started in frame', { frameUrl: frame.url(), src: frameSrc });
        playingSrc = frameSrc;
        break;
      }
    }
    return playingSrc;
  }

  async _openHlsPreview(browser, m3u8Url, log = moduleLog) {
    try {
      log.debug('opening HLS preview page', { m3u8Url });
      const playPage = await browser.newPage();
      await playPage.setViewport({ width: 1280, height: 720 });
      await playPage.setContent(this._buildPreviewHtml(m3u8Url), { waitUntil: 'domcontentloaded' });
      await playPage.close().catch(() => {});
      log.debug('HLS preview page closed');
    } catch (err) {
      log.warn('HLS preview failed', { error: err });
    }
  }

  _buildPreviewHtml(m3u8Url) {
    return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>m3u8 player</title>
  </head>
  <body style="margin:0; background:#000; display:flex; align-items:center; justify-content:center; height:100vh;">
    <video id="video" controls style="width:100%; height:100%; max-width:1280px; max-height:720px; background:#000"></video>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@1.4.0/dist/hls.min.js"></script>
    <script>
      (function () {
        const url = ${JSON.stringify(m3u8Url)};
        const video = document.getElementById('video');
        if (window.Hls && Hls.isSupported()) {
          const hls = new Hls({
            manifestLoadingTimeOut: 30000,
            xhrSetup: function (xhr) {
              xhr.timeout = 30000;
            },
          });
          hls.loadSource(url);
          hls.attachMedia(video);
          hls.on(Hls.Events.MANIFEST_PARSED, function () {
            video.play().catch(() => {});
          });
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
          video.src = url;
          video.addEventListener('loadedmetadata', function () {
            video.play().catch(() => {});
          });
        }
      })();
    </script>
  </body>
</html>`;
  }
}

module.exports = { StreamScraper };
