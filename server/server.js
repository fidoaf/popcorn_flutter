const http = require('http');
const https = require('https');
const puppeteer = require('puppeteer');

const PORT = Number(process.env.PORT || 3000);
const MAX_CONCURRENT_SCRAPES = 1;

let browser;
let activeScrapes = 0;
const streamCache = new Map(); // Store detected m3u8 URLs

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
  if (!browser) {
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
        const rtype = req.resourceType();

        if (!foundM3u8 && lower.includes('.m3u8')) {
          foundM3u8 = url;
          resolveM3u8?.(url);
        }

        const suspect =
          (rtype === 'script') &&
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
        const contentType = (headers['content-type'] || headers['Content-Type'] || '').toLowerCase();

        if (!foundM3u8 && (contentType.includes('application/vnd.apple.mpegurl') || contentType.includes('vnd.apple.mpegurl') || contentType.includes('application/x-mpegurl') || contentType.includes('mpegurl'))) {
          foundM3u8 = url;
          resolveM3u8?.(url);
          return;
        }

        if (!foundM3u8 && contentType.includes('text')) {
          const text = await res.text().catch(() => null);
          if (text && text.includes('.m3u8')) {
            const match = text.match(/https?:\/\/[^\s"']+?\.m3u8/);
            const detected = match ? match[0] : null;
            if (detected) {
              foundM3u8 = detected;
              resolveM3u8?.(detected);
            }
          }
        }
      } catch (_) {}
    });

    await page.evaluateOnNewDocument(() => {
      try {
        const blocked = ['about:blank'];
        const wrap = (obj, prop) => {
          try {
            const original = obj[prop];
            if (typeof original === 'function') {
              obj[prop] = function (url) {
                if (blocked.some((b) => String(url).includes(b))) return;
                return original.call(this, url);
              };
            }
          } catch (_) {}
        };

        wrap(window.location, 'assign');
        wrap(window.location, 'replace');
        try { window.open = () => null; } catch (_) {}
        try { Object.defineProperty(window, 'name', { get: () => '', configurable: true }); } catch (_) {}
        try { history.pushState = function () {}; history.replaceState = function () {}; } catch (_) {}
      } catch (_) {}
    });

    await page.evaluateOnNewDocument(() => {
      try { Object.defineProperty(navigator, 'webdriver', { get: () => false }); } catch (_) {}
      try { window.open = () => null; window.alert = () => null; window.confirm = () => true; window.prompt = () => null; } catch (_) {}
      try {
        const originalAssign = window.location.assign;
        window.location.assign = function (url) {
          if (String(url).includes('about:blank')) return;
          return originalAssign.call(this, url);
        };

        const originalReplace = window.location.replace;
        window.location.replace = function (url) {
          if (String(url).includes('about:blank')) return;
          return originalReplace.call(this, url);
        };
      } catch (_) {}
    });

    page.on('dialog', async (dialog) => {
      try {
        await dialog.dismiss();
      } catch (_) {}
    });

    browserInstance.on('targetcreated', async (target) => {
      try {
        const popupPage = await target.page();
        if (popupPage) {
          await popupPage.close().catch(() => {});
        }
      } catch (_) {}
    });

    await page.goto(urlOrigen, { waitUntil: 'networkidle2', timeout: 30000 });

    let playingSrc = await page.evaluate(async () => {
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
    });

    if (!playingSrc) {
      const frames = page.frames();
      for (const frame of frames) {
        try {
          const frameSrc = await frame.evaluate(async () => {
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
          }).catch(() => null);

          if (frameSrc) {
            playingSrc = frameSrc;
            break;
          }
        } catch (_) {}
      }
    }

    let detectedM3u8 = null;
    try {
      detectedM3u8 = await Promise.race([
        m3u8Promise,
        new Promise((resolve) => setTimeout(() => resolve(null), 20000)),
      ]);
    } catch (_) {
      detectedM3u8 = foundM3u8 || null;
    }

    const m3u8ToPlay = detectedM3u8 || foundM3u8;
    if (m3u8ToPlay) {
      try {
        const playPage = await browserInstance.newPage();
        await playPage.setViewport({ width: 1280, height: 720 });

        const html = `<!doctype html>
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
        const url = ${JSON.stringify(m3u8ToPlay)};
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

        await playPage.setContent(html, { waitUntil: 'networkidle0' });
        await playPage.close().catch(() => {});
      } catch (_) {}
    }

    return {
      imdbId,
      page: urlOrigen,
      playing: !!playingSrc,
      src: playingSrc,
      m3u8: detectedM3u8 || foundM3u8,
    };
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

    if (url.pathname === '/proxy-stream') {
      const streamUrl = url.searchParams.get('url');
      if (!streamUrl) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Missing url parameter' }));
        return;
      }

      try {
        const isHttps = streamUrl.startsWith('https');
        const client = isHttps ? https : http;
        
        const streamReq = client.get(streamUrl, { 
          headers: { 'User-Agent': 'Mozilla/5.0' } 
        }, (streamRes) => {
          const contentType = streamRes.headers['content-type'] || '';
          const isM3u8 = contentType.includes('application/vnd.apple.mpegurl') || 
                         contentType.includes('mpegurl') ||
                         streamUrl.includes('.m3u8');

          if (isM3u8) {
            // For m3u8 files, collect body and rewrite URLs
            let body = '';
            streamRes.on('data', (chunk) => { body += chunk; });
            streamRes.on('end', () => {
              const m3u8BaseUrl = streamUrl.substring(0, streamUrl.lastIndexOf('/') + 1);
              const m3u8Domain = new URL(streamUrl).origin;

              const rewritten = body.split('\n').map((line) => {
                if (line.startsWith('#') || !line.trim()) return line;
                
                let fullUrl;
                if (line.startsWith('http://') || line.startsWith('https://')) {
                  fullUrl = line;
                } else if (line.startsWith('/')) {
                  fullUrl = m3u8Domain + line;
                } else {
                  fullUrl = new URL(line, m3u8BaseUrl).href;
                }
                
                return '/proxy-stream?url=' + encodeURIComponent(fullUrl);
              }).join('\n');

              res.writeHead(200, {
                'Content-Type': 'application/vnd.apple.mpegurl',
                'Access-Control-Allow-Origin': '*',
                'Cache-Control': 'no-cache'
              });
              res.end(rewritten);
            });
          } else {
            // For non-m3u8 content, stream as-is
            res.writeHead(streamRes.statusCode, {
              'Content-Type': contentType || 'application/octet-stream',
              'Access-Control-Allow-Origin': '*'
            });
            streamRes.pipe(res);
          }
        });

        streamReq.on('error', (err) => {
          res.writeHead(502, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: err.message }));
        });
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
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

    if (url.pathname === '/proxy-m3u8') {
      const imdbId = url.searchParams.get('id');
      let cachedUrl = streamCache.get(imdbId);

      // If not cached, run extraction to detect m3u8
      if (!cachedUrl) {
        if (activeScrapes >= MAX_CONCURRENT_SCRAPES) {
          res.writeHead(503, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Too many active scrapes; retry later.' }));
          return;
        }

        activeScrapes += 1;
        try {
          const extraction = await extractUrlReproductor(imdbId);
          cachedUrl = extraction.m3u8;
          if (cachedUrl) {
            streamCache.set(imdbId, cachedUrl);
          }
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Extraction failed: ' + err.message }));
          activeScrapes -= 1;
          return;
        } finally {
          activeScrapes -= 1;
        }
      }

      if (!cachedUrl) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Stream not found for ' + imdbId }));
        return;
      }

      try {
        const isHttps = cachedUrl.startsWith('https');
        const client = isHttps ? https : http;

        const m3u8Req = client.get(cachedUrl, { 
          headers: { 'User-Agent': 'Mozilla/5.0' } 
        }, (m3u8Res) => {
          let body = '';
          m3u8Res.on('data', (chunk) => { body += chunk; });
          m3u8Res.on('end', () => {
            // Determine base URL for resolving relative paths
            const m3u8BaseUrl = cachedUrl.substring(0, cachedUrl.lastIndexOf('/') + 1);
            const m3u8Domain = new URL(cachedUrl).origin;

            // Rewrite segment URLs to use the proxy
            const rewritten = body.split('\n').map((line) => {
              // Skip comments and empty lines
              if (line.startsWith('#') || !line.trim()) return line;
              
              let fullUrl;
              
              if (line.startsWith('http://') || line.startsWith('https://')) {
                // Absolute URL
                fullUrl = line;
              } else if (line.startsWith('/')) {
                // Absolute path - resolve against domain
                fullUrl = m3u8Domain + line;
              } else {
                // Relative path - resolve against base URL
                fullUrl = new URL(line, m3u8BaseUrl).href;
              }
              
              return '/proxy-stream?url=' + encodeURIComponent(fullUrl);
            }).join('\n');

            res.writeHead(200, {
              'Content-Type': 'application/vnd.apple.mpegurl',
              'Access-Control-Allow-Origin': '*',
              'Cache-Control': 'no-cache'
            });
            res.end(rewritten);
          });
        });

        m3u8Req.on('error', (err) => {
          res.writeHead(502, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: err.message }));
        });
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
      return;
    }

    if (url.pathname === '/player') {
      const imdbId = url.searchParams.get('id') || 'tt1300854';
      
      // Return player HTML immediately, extraction happens on-demand in /proxy-m3u8
      const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>HLS Player - ${imdbId}</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { background: #000; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
      .container { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
      video { width: 100%; max-width: 1280px; height: auto; max-height: 720px; background: #000; border-radius: 8px; }
      .info { color: #999; margin-top: 20px; text-align: center; font-size: 11px; word-break: break-all; }
      code { background: #1a1a1a; padding: 2px 4px; border-radius: 3px; display: inline-block; }
      .status { color: #666; font-size: 12px; margin-top: 10px; }
    </style>
  </head>
  <body>
    <div class="container">
      <video id="video" controls autoplay></video>
      <div class="info">
        <p>ID: <code>${imdbId}</code></p>
        <p class="status" id="status">Loading...</p>
      </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@1.4.0/dist/hls.min.js"><\/script>
    <script>
      (function () {
        const imdbId = ${JSON.stringify(imdbId)};
        const video = document.getElementById('video');
        const statusEl = document.getElementById('status');
        const proxiedM3u8 = '/proxy-m3u8?id=' + encodeURIComponent(imdbId);
        
        if (window.Hls && Hls.isSupported()) {
          const hls = new Hls({ debug: false });
          
          hls.on(Hls.Events.MANIFEST_LOADING, () => statusEl.textContent = 'Loading manifest...');
          hls.on(Hls.Events.MANIFEST_PARSED, () => {
            statusEl.textContent = 'Ready';
            video.play().catch(() => {});
          });
          hls.on(Hls.Events.ERROR, function (event, data) {
            statusEl.textContent = 'Error: ' + (data.details || data.type);
            if (data.fatal) console.error('[hls] Fatal Error:', data);
          });
          
          hls.loadSource(proxiedM3u8);
          hls.attachMedia(video);
        } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
          statusEl.textContent = 'Loading with native playback...';
          video.src = proxiedM3u8;
          video.addEventListener('loadedmetadata', function () {
            statusEl.textContent = 'Ready';
            video.play().catch(() => {});
          });
          video.addEventListener('error', function () {
            statusEl.textContent = 'Playback error';
          });
        } else {
          statusEl.textContent = 'HLS not supported';
        }
      })();
    <\/script>
  </body>
</html>`;

      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
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