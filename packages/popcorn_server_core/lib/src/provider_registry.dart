const defaultMediaProviderId = 'vidsrcbuzz';

abstract interface class MediaProvider {
  String get id;
  String get label;
}

final class ProviderSummary {
  const ProviderSummary({required this.id, required this.label});

  final String id;
  final String label;
}

final class MediaProviderRegistry {
  factory MediaProviderRegistry(Iterable<MediaProvider> providers, {String defaultProviderId = defaultMediaProviderId}) {
    final byId = <String, MediaProvider>{};
    for (final provider in providers) {
      byId[provider.id] = provider;
    }
    final selectedDefault = byId.containsKey(defaultProviderId)
        ? defaultProviderId
        : byId.isEmpty
        ? defaultProviderId
        : byId.keys.first;
    return MediaProviderRegistry._(Map.unmodifiable(byId), selectedDefault);
  }

  const MediaProviderRegistry._(this._providers, this.defaultProviderId);

  final Map<String, MediaProvider> _providers;
  final String defaultProviderId;

  Iterable<MediaProvider> get allProviders => _providers.values;

  Set<String> get providerIds => _providers.keys.toSet();

  bool contains(String id) => _providers.containsKey(id);

  MediaProvider get(String id) {
    final provider = _providers[id];
    if (provider == null) throw const UnsupportedMediaProvider();
    return provider;
  }

  List<ProviderSummary> list() => [
    if (_providers[defaultProviderId] case final provider?) ProviderSummary(id: provider.id, label: provider.label),
    for (final provider in _providers.values)
      if (provider.id != defaultProviderId) ProviderSummary(id: provider.id, label: provider.label),
  ];
}

final class UnsupportedMediaProvider implements Exception {
  const UnsupportedMediaProvider();

  String get message => 'Unsupported media provider';
  int get statusCode => 400;

  @override
  String toString() => message;
}
