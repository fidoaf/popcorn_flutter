const DEFAULT_PROVIDER_ID = 'vidsrcbuzz';

class ProviderRegistry {
  constructor(providers, defaultProviderId = DEFAULT_PROVIDER_ID) {
    this.providers = new Map(providers.map((provider) => [provider.id, provider]));
    this.defaultProviderId = this.providers.has(defaultProviderId)
      ? defaultProviderId
      : this.providers.keys().next().value || defaultProviderId;
  }

  list() {
    return [...this.providers.values()]
      .sort((left, right) => Number(right.id === this.defaultProviderId) - Number(left.id === this.defaultProviderId))
      .map(({ id, label }) => ({ id, label }));
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