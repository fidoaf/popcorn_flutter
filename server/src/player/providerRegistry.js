const DEFAULT_PROVIDER_ID = 'vidsrcbuzz';

class ProviderRegistry {
  constructor(providers) {
    this.providers = new Map(providers.map((provider) => [provider.id, provider]));
  }

  list() {
    return [...this.providers.values()].map(({ id, label }) => ({ id, label }));
  }

  get(id = DEFAULT_PROVIDER_ID) {
    const provider = this.providers.get(id);
    if (!provider) {
      const error = new Error('Unsupported media provider');
      error.statusCode = 400;
      throw error;
    }
    return provider;
  }
}

module.exports = { DEFAULT_PROVIDER_ID, ProviderRegistry };