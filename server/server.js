#!/usr/bin/env node

const { mediaFromQuery } = require('./src/player/mediaRequest');
const { createPlayerServer } = require('./src/player/playerServer');
const { DEFAULT_PROVIDER_ID } = require('./src/player/providerRegistry');
const { createProviderRegistry } = require('./src/player/providerFactory');
const { ResourceProxy } = require('./src/player/resourceProxy');

function createDefaultProviders(options = {}) {
  return createProviderRegistry(options);
}

function createServer(initialMedia = null, dependencies = {}) {
  const providers = dependencies.providers || createDefaultProviders({
    providerConfig: dependencies.providerConfig,
    configPath: dependencies.providerConfigPath,
    fetchImpl: dependencies.fetchImpl,
    timeoutMs: dependencies.timeoutMs,
  });
  const resourceProxy = dependencies.resourceProxy || new ResourceProxy({
    providers,
    fetchImpl: dependencies.fetchImpl,
    timeoutMs: dependencies.timeoutMs,
    resourceTtlMs: dependencies.resourceTtlMs,
  });
  return createPlayerServer({
    initialMedia,
    providers,
    resourceProxy,
    subtitleRefs: dependencies.subtitleRefs,
  });
}

function extract(type, id, season = '0', episode = '0', providerId = DEFAULT_PROVIDER_ID, dependencies = {}) {
  const providers = dependencies.providers || createDefaultProviders({
    providerConfig: dependencies.providerConfig,
    configPath: dependencies.providerConfigPath,
    fetchImpl: dependencies.fetchImpl,
    timeoutMs: dependencies.timeoutMs,
  });
  return providers.get(providerId).extract({ providerId, type, id, season, episode });
}

function parseInitialMedia(args, providers) {
  const [type, id, season, episode] = args;
  if (args.length === 0) return null;
  const params = new URLSearchParams();
  if (type !== undefined) params.set('type', type);
  if (id !== undefined) params.set('id', id);
  if (season !== undefined) params.set('season', season);
  if (episode !== undefined) params.set('episode', episode);
  return mediaFromQuery(params, providers);
}

function main() {
  const providers = createDefaultProviders();
  let initialMedia;
  try {
    initialMedia = parseInitialMedia(process.argv.slice(2), providers);
  } catch (error) {
    console.error(`Invalid media arguments: ${error.message}`);
    console.error('Usage: node server.js [movie <imdb-or-tmdb-id> | tv <imdb-or-tmdb-id> <season> <episode>]');
    process.exitCode = 1;
    return;
  }

  const port = Number(process.env.PORT || 3001);
  const server = createServer(initialMedia, { providers });
  let shuttingDown = false;

  function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[server] ${signal}; closing HTTP server`);
    const timeout = setTimeout(() => {
      console.error('[server] shutdown timed out; closing remaining connections');
      server.closeAllConnections();
    }, 10000);
    timeout.unref();
    server.close((error) => {
      clearTimeout(timeout);
      if (error) {
        console.error('[server] HTTP server close failed:', error);
        process.exitCode = 1;
      } else {
        console.log('[server] HTTP server closed');
      }
    });
  }

  process.once('SIGTERM', () => shutdown('SIGTERM'));
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    console.error('[server] unhandled promise rejection:', reason);
    process.exitCode = 1;
    shutdown('unhandledRejection');
  });
  process.on('uncaughtException', (error) => {
    console.error('[server] uncaught exception:', error);
    process.exitCode = 1;
    shutdown('uncaughtException');
  });

  server.listen(port, '0.0.0.0', () => {
    console.log(`Player available at http://127.0.0.1:${port}/`);
  });
}

if (require.main === module) main();

module.exports = { createServer, extract, parseInitialMedia };