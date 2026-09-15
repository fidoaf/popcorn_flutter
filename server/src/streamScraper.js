const { M3u8Detector } = require('./m3u8Detector');
const { blockNavigationHijacks, maskAutomation } = require('./pageHardening');

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
  }

  async extract(media) {
    const sourceUrl = this.provider.buildSourceUrl(media);
    const browser = await this.browserPool.acquire();
    const page = await browser.newPage();

    try {
      await this._preparePage(page);
      const detector = new M3u8Detector(page);
      await detector.attach();

      await page.goto(sourceUrl, { waitUntil: 'networkidle2', timeout: this.navigationTimeoutMs });

      const playingSrc = await this._attemptPlayback(page);
      const m3u8 = await detector.waitFor(this.m3u8WaitMs);
      const resolvedM3u8 = m3u8 || detector.found;

      if (resolvedM3u8) {
        await this._openHlsPreview(browser, resolvedM3u8);
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

  async _attemptPlayback(page) {
    let playingSrc = await page.evaluate(playInDocument);
    if (playingSrc) return playingSrc;

    for (const frame of page.frames()) {
      const frameSrc = await frame.evaluate(playInFrame).catch(() => null);
      if (frameSrc) {
        playingSrc = frameSrc;
        break;
      }
    }
    return playingSrc;
  }

  async _openHlsPreview(browser, m3u8Url) {
    try {
      const playPage = await browser.newPage();
      await playPage.setViewport({ width: 1280, height: 720 });
      await playPage.setContent(this._buildPreviewHtml(m3u8Url), { waitUntil: 'networkidle0' });
      await playPage.close().catch(() => {});
    } catch (_) {}
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
          const hls = new Hls();
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
