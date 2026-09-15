const { createApp } = require('./src/app');
const { createLogger } = require('./src/logger');

const log = createLogger('server');

const { config, server, browserPool } = createApp();

process.on('unhandledRejection', (reason) => {
  log.error('unhandledRejection', { reason });
});
process.on('uncaughtException', (err) => {
  log.error('uncaughtException', { error: err });
});

const shutdown = async (signal) => {
  log.warn('shutdown signal received', { signal });
  server.close(() => log.info('http server closed'));
  await browserPool.close().catch((err) => log.warn('browser close failed', { error: err }));
  process.exit(0);
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

server.listen(config.port, () => {
  log.info('server listening', { port: config.port });
});