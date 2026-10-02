const fs = require('node:fs');
const path = require('node:path');
const { DEFAULT_PROVIDER_ID, ProviderRegistry } = require('./providerRegistry');
const { RedirectProvider } = require('./redirectProvider');
const { VidSrcBuzzProvider } = require('./vidsrcBuzzProvider');

const DEFAULT_CONFIG_PATH = path.resolve(__dirname, '../../config/media_source_providers.json');

function loadProviderConfig(configPath = process.env.MEDIA_SOURCE_PROVIDERS_PATH || DEFAULT_CONFIG_PATH) {
  return JSON.parse(fs.readFileSync(path.resolve(configPath), 'utf8'));
}

function createProviderRegistry(options = {}) {
  const config = options.providerConfig || loadProviderConfig(options.configPath);
  if (!Array.isArray(config.providers) || config.providers.length === 0) {
    throw new TypeError('Media source configuration must list at least one provider');
  }

  const providers = [];
  const ids = new Set();
  for (const definition of config.providers) {
    if (!definition || typeof definition.name !== 'string' || !definition.name.trim()) {
      throw new TypeError('Each media source provider must have a non-empty name');
    }
    const id = providerId(definition.name);
    if (id === 'render') continue;
    if (ids.has(id)) throw new TypeError(`Duplicate media source provider: ${definition.name}`);
    ids.add(id);

    if (id === DEFAULT_PROVIDER_ID) {
      providers.push(new VidSrcBuzzProvider({ fetchImpl: options.fetchImpl, timeoutMs: options.timeoutMs }));
    } else {
      providers.push(new RedirectProvider({
        id,
        label: definition.name,
        scheme: definition.scheme,
        host: definition.host,
        path: definition.path,
        parameters: definition.parameters,
      }));
    }
  }

  if (providers.length === 0) throw new TypeError('Media source configuration has no supported providers');
  const configuredDefault = providerId(config.initialProvider || '');
  const defaultProviderId = ids.has(configuredDefault)
    ? configuredDefault
    : ids.has(DEFAULT_PROVIDER_ID) ? DEFAULT_PROVIDER_ID : providers[0].id;
  return new ProviderRegistry(providers, defaultProviderId);
}

function providerId(name) {
  return String(name).toLowerCase().replace(/[^a-z0-9]/g, '');
}

module.exports = { createProviderRegistry, loadProviderConfig };