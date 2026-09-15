const http = require('http');
const { loadConfig } = require('./config');
const { AuthService } = require('./auth');
const { VidsrcProvider } = require('./media');
const { BrowserPool } = require('./browserPool');
const { ConcurrencyLimiter } = require('./concurrencyLimiter');
const { StreamScraper } = require('./streamScraper');
const { StreamProxy } = require('./streamProxy');
const { Controllers } = require('./controllers');
const { Router } = require('./router');
const { createLogger } = require('./logger');

const log = createLogger('app');

// Composition root: builds and wires every component in one place. The rest of
// the codebase depends only on abstractions passed in here (Dependency
// Inversion), which keeps modules independently testable.
function createApp(env = process.env) {
  const config = loadConfig(env);
  log.info('creating app', {
    port: config.port,
    maxConcurrentScrapes: config.maxConcurrentScrapes,
    authEnabled: config.apiTokens.size > 0,
    chromePath: config.chromePath || 'bundled',
    logLevel: env.LOG_LEVEL || 'debug',
  });

  const auth = new AuthService(config);
  const browserPool = new BrowserPool({ chromePath: config.chromePath });
  const limiter = new ConcurrencyLimiter(config.maxConcurrentScrapes);
  const provider = new VidsrcProvider();
  const scraper = new StreamScraper({ browserPool, provider, config });
  const streamProxy = new StreamProxy();
  const streamCache = new Map();

  const controllers = new Controllers({
    config,
    auth,
    scraper,
    streamProxy,
    limiter,
    streamCache,
  });

  const router = new Router({ auth })
    .register('/health', (req, res) => controllers.health(req, res))
    .register('/favicon.ico', (req, res) => controllers.favicon(req, res))
    .register('/proxy-stream', (req, res, url) => controllers.proxyStream(req, res, url))
    .register('/scrape', (req, res, url) => controllers.scrape(req, res, url))
    .register('/proxy-m3u8', (req, res, url) => controllers.proxyM3u8(req, res, url))
    .register('/player', (req, res, url) => controllers.player(req, res, url))
    .register('/', (req, res) => controllers.landing(req, res));

  const server = http.createServer((req, res) => router.handle(req, res));
  server.on('clientError', (err, socket) => {
    log.warn('client error', { error: err });
    if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
  });

  log.info('app created');
  return { config, server, browserPool };
}

module.exports = { createApp };
