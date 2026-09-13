const http = require('http');
const puppeteer = require('puppeteer');

const PORT = Number(process.env.PORT || 3000);

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

let browser;

async function getBrowser() {
  if (!browser || !browser.isConnected()) {
    browser = await puppeteer.launch(browserConfig);
  }
  return browser;
}

async function extractUrlReproductor(imdbId) {
  const urlOrigen = `https://vidsrc.ir/embed/movie/${imdbId}`;
  const page = (await getBrowser()).newPage();

  return page.then(async (p) => {
    try {
      await p.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      await p.goto(urlOrigen, { waitUntil: 'networkidle2', timeout: 30000 });
      const result = await p.evaluate(() => {
        const video = document.querySelector('video');
        return video ? (video.currentSrc || video.src || null) : null;
      });
      return { imdbId, page: urlOrigen, src: result };
    } finally {
      await p.close();
    }
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }
    const imdbId = url.searchParams.get('imdbId') || 'tt1300854';
    const result = await extractUrlReproductor(imdbId);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, result }));
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: error.message }));
  }
});

server.listen(PORT, () => {
  console.log(`Server listening on ${PORT}`);
});