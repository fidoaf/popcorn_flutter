const path = require('path');

// Centralized, immutable runtime configuration derived from the environment.
// Keeping this in one place means the rest of the app depends on plain values
// instead of reaching into `process.env` directly (Dependency Inversion).
function parseTokens(raw) {
  return new Set(
    (raw || '')
      .split(',')
      .map((token) => token.trim())
      .filter(Boolean),
  );
}

function loadConfig(env = process.env) {
  return Object.freeze({
    port: Number(env.PORT || 3000),
    faviconPath: path.join(__dirname, '..', 'app_icon.ico'),
    maxConcurrentScrapes: 1,
    apiTokens: parseTokens(env.API_TOKENS || env.AUTH_TOKEN),
    chromePath: env.PUPPETEER_EXECUTABLE_PATH || env.CHROME_BIN || null,
    publicPaths: new Set(['/', '/health', '/favicon.ico']),
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    scrapeTimeoutMs: 30000,
    m3u8WaitMs: 20000,
  });
}

module.exports = { loadConfig, parseTokens };
