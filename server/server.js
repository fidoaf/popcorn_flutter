const http = require('http');
const puppeteer = require('puppeteer');

const PORT = Number(process.env.PORT || 3000);
const MAX_CONCURRENT_SCRAPES = 1;

let browser;
let activeScrapes = 0;

const browserConfig = {
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
    await page.setJavaScriptEnabled(true);
    await page.setCacheEnabled(false);
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    await page.setViewport({ width: 1280, height: 800 });

    await page.goto(urlOrigen, { waitUntil: 'domcontentloaded', timeout: 20000 });

    const result = await page.evaluate(() => {
      const video = document.querySelector('video');
      return video ? (video.currentSrc || video.src || null) : null;
    });

    return { imdbId, page: urlOrigen, src: result };
  } finally {
    try {
      await page.close();
    } catch (_) {}
  }
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);

    if (url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, activeScrapes }));
      return;
    }

    if (url.pathname === '/scrape') {
      if (activeScrapes >= MAX_CONCURRENT_SCRAPES) {
        res.writeHead(429, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: 'Too many active scrapes; retry later.' }));
        return;
      }

      activeScrapes += 1;
      try {
        const imdbId = url.searchParams.get('imdbId') || 'tt1300854';
        const result = await extractUrlReproductor(imdbId);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true, result }));
      } finally {
        activeScrapes -= 1;
      }
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'not_found' }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: error.message }));
  }
});

server.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});