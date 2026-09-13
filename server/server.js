const http = require('http');
const { URL } = require('url');
const puppeteer = require('puppeteer');

const PORT = Number(process.env.PORT || 3000);

let browser;

const browserConfig = {
  headless: 'new',
  args: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-software-rasterizer',
  ],
};

const chromePath = process.env.PUPPETEER_EXECUTABLE_PATH || process.env.CHROME_BIN;
if (chromePath) {
  browserConfig.executablePath = chromePath;
}

async function getBrowser() {
  if (!browser || !browser.isConnected()) {
    browser = await puppeteer.launch(browserConfig);
  }

  return browser;
}

async function extractUrlReproductor(imdbId) {
  const urlOrigen = `https://vidsrc.ir/embed/movie/${imdbId}`;

  const browserInstance = await getBrowser();
  const page = await browserInstance.newPage();

  try {
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );
    await page.setViewport({ width: 1280, height: 800 });

    await page.setRequestInterception(true);
    let foundM3u8 = null;
    let resolveM3u8;
    const m3u8Promise = new Promise((resolve) => {
      resolveM3u8 = resolve;
    });

    page.on('request', async (req) => {
      try {
        const url = req.url();
        const lower = url.toLowerCase();

        if (!foundM3u8 && lower.includes('.m3u8')) {
          foundM3u8 = url;
          resolveM3u8?.(url);
        }

        if (lower === 'about:blank' || lower.includes('about:blank')) {
          return req.abort();
        }

        const suspect =
          req.resourceType() === 'script' &&
          ['devtool', 'anti', 'block', 'detect', 'devtools'].some((token) => lower.includes(token));

        if (suspect) {
          return req.respond({
            status: 200,
            contentType: 'application/javascript',
            body: '/* neutralized by puppeteer */',
          });
        }

        req.continue();
      } catch (_err) {
        try {
          req.continue();
        } catch (_) {}
      }
    });

    page.on('response', async (res) => {
      try {
        const url = res.url();
        const lower = url.toLowerCase();

        if (!foundM3u8 && lower.includes('.m3u8')) {
          foundM3u8 = url;
          resolveM3u8?.(url);
          return;
        }

        const headers = res.headers ? res.headers() : {};
        const contentType = (headers['content-type'] || '').toLowerCase();

        if (
          !foundM3u8 &&
          ['application/vnd.apple.mpegurl', 'application/x-mpegurl'].some((token) =>
            contentType.includes(token),
          )
        ) {
          foundM3u8 = url;
          resolveM3u8?.(url);
          return;
        }

        if (!foundM3u8 && contentType.includes('text')) {
          const text = await res.text().catch(() => null);
          if (text && text.includes('.m3u8')) {
            const match = text.match(/https?:\/\/[^\s"']+?\.m3u8/);
            if (match) {
              foundM3u8 = match[0];
              resolveM3u8?.(match[0]);
            }
          }
        }
      } catch (_) {}
    });

    page.on('dialog', async (dialog) => {
      try {
        await dialog.dismiss();
      } catch (_) {}
    });

    await page.goto(urlOrigen, { waitUntil: 'networkidle2', timeout: 30000 });

    let playingSrc = await page.evaluate(async () => {
      try {
        const tryPlay = async (video) => {
          if (!video) return null;
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

        const selectors = [
          '.play',
          '.play-button',
          '.vjs-play-control',
          '.jw-icon-play',
          'button[aria-label="Play"]',
          'button[title="Play"]',
        ];

        for (const selector of selectors) {
          const button = document.querySelector(selector);
          if (button) {
            button.click();
            break;
          }
        }

        return null;
      } catch (_) {
        return null;
      }
    });

    if (!playingSrc) {
      const frames = page.frames();
      for (const frame of frames) {
        const src = await frame.evaluate(async () => {
          try {
            const video = document.querySelector('video');
            if (video) {
              video.muted = false;
              await video.play().catch(() => {});
              return video.currentSrc || video.src || null;
            }
          } catch (_) {}

          return null;
        }).catch(() => null);

        if (src) {
          playingSrc = src;
          break;
        }
      }
    }

    let detectedM3u8 = await Promise.race([
      m3u8Promise,
      new Promise((resolve) => setTimeout(() => resolve(null), 20000)),
    ]).catch(() => null);

    detectedM3u8 = detectedM3u8 || foundM3u8 || null;

    return {
      page: urlOrigen,
      imdbId,
      playing: !!playingSrc,
      src: playingSrc || null,
      m3u8: detectedM3u8,
    };
  } finally {
    try {
      await page.close();
    } catch (_) {}
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (requestUrl.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, status: 'healthy' }));
      return;
    }

    if (requestUrl.pathname === '/scrape') {
      const imdbId = requestUrl.searchParams.get('imdbId') || 'tt1300854';
      const result = await extractUrlReproductor(imdbId);

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, result }));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'not_found' }));
  } catch (error) {
    console.error('server error:', error);
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: error.message || 'internal_server_error' }));
  }
});

server.listen(PORT, () => {
  console.log(`Render Puppeteer server listening on port ${PORT}`);
});

process.on('SIGINT', async () => {
  try {
    if (browser) await browser.close();
  } catch (_) {}
  process.exit(0);
});

process.on('SIGTERM', async () => {
  try {
    if (browser) await browser.close();
  } catch (_) {}
  process.exit(0);
});
