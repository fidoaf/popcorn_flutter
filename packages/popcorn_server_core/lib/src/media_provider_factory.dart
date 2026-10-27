import 'browser_response_capture.dart';
import 'cinesrc_provider.dart';
import 'nxsha_provider.dart';
import 'onlypelis_provider.dart';
import 'provider_http_client.dart';
import 'provider_registry.dart';
import 'redirect_media_provider.dart';
import 'same_origin_browser_fetch.dart';
import 'vidsrc_buzz_provider.dart';

typedef ProviderOverride = MediaProvider Function(MediaProviderDefinition definition);

final class MediaProviderDefinition {
  MediaProviderDefinition({
    required this.name,
    required this.id,
    required this.host,
    required this.scheme,
    required this.path,
    required Map<String, String> parameters,
  }) : parameters = Map.unmodifiable(parameters);

  factory MediaProviderDefinition.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Provider definition must be an object');
    }
    final name = json['name'];
    final host = json['host'];
    final scheme = json['scheme'];
    final path = json['path'];
    final rawParameters = json['parameters'];
    if (name is! String || name.trim().isEmpty || host is! String || scheme is! String || path is! String || (rawParameters != null && rawParameters is! Map)) {
      throw const FormatException('Provider definition requires valid name, host, scheme, path and parameters');
    }
    final parameters = <String, String>{};
    if (rawParameters is Map) {
      for (final entry in rawParameters.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const FormatException('Provider parameter names and values must be strings');
        }
        parameters[entry.key as String] = entry.value as String;
      }
    }
    final normalizedName = name.trim();
    return MediaProviderDefinition(
      name: normalizedName,
      id: providerIdFromName(normalizedName),
      host: host,
      scheme: scheme,
      path: path,
      parameters: parameters,
    );
  }

  final String name;
  final String id;
  final String host;
  final String scheme;
  final String path;
  final Map<String, String> parameters;
}

final class CoreMediaProviderFactory {
  const CoreMediaProviderFactory._();

  static MediaProviderRegistry fromJson({
    required Map<String, Object?> config,
    required ProviderHttpClient httpClient,
    required ProviderHttpPostClient postClient,
    BrowserResponseCaptureClient? browserResponseCaptureClient,
    SameOriginBrowserFetchClient? sameOriginBrowserFetchClient,
    Map<String, ProviderOverride> overrides = const {},
  }) {
    final definitions = config['providers'];
    if (definitions is! List || definitions.isEmpty) {
      throw const FormatException('Media source configuration must list at least one provider');
    }
    final providers = <MediaProvider>[];
    final ids = <String>{};
    for (final value in definitions) {
      final definition = MediaProviderDefinition.fromJson(value);
      if (definition.id == 'render') continue;
      if (!ids.add(definition.id)) {
        throw FormatException('Duplicate media source provider: ${definition.name}');
      }
      final override = overrides[definition.id];
      final provider = override != null
          ? override(definition)
          : switch (definition.id) {
              'vidsrcbuzz' => VidSrcBuzzProvider(httpClient: httpClient),
              'onlypelis' => OnlyPelisProvider(httpClient: httpClient, postClient: postClient),
              'nxsha' => NxshaProvider(
                httpClient: httpClient,
                browserFetchClient: sameOriginBrowserFetchClient,
                host: definition.host,
                scheme: definition.scheme,
                path: definition.path,
                parameters: definition.parameters,
              ),
              'cinesrc' when browserResponseCaptureClient != null => CinesrcProvider(
                browser: browserResponseCaptureClient,
                host: definition.host,
                scheme: definition.scheme,
                path: definition.path,
                parameters: definition.parameters,
              ),
              _ => RedirectMediaProvider(
                id: definition.id,
                label: definition.name,
                host: definition.host,
                scheme: definition.scheme,
                path: definition.path,
                parameters: definition.parameters,
              ),
            };
      if (provider.id != definition.id) {
        throw FormatException('Provider override for ${definition.id} returned ${provider.id}');
      }
      providers.add(provider);
    }
    if (providers.isEmpty) {
      throw const FormatException('Media source configuration has no supported providers');
    }
    final configuredDefault = providerIdFromName('${config['initialProvider'] ?? ''}');
    final defaultProviderId = ids.contains(configuredDefault)
        ? configuredDefault
        : ids.contains(defaultMediaProviderId)
        ? defaultMediaProviderId
        : providers.first.id;
    return MediaProviderRegistry(providers, defaultProviderId: defaultProviderId);
  }
}

String providerIdFromName(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
