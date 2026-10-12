import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:popcorn_flutter/src/player/infrastructure/media_source/configurable_media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/json_media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_preferences.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_definition.dart';

/// Builds the [ConfigurableMediaSourceProvider] used by the app from a JSON
/// definition, so the available streaming backends (and the default one) can be
/// changed as data rather than code.
///
/// The expected JSON shape is:
/// ```json
/// {
///   "initialProvider": "nxsha",
///   "providers": [
///     {
///       "name": "nxsha",
///       "scheme": "https",
///       "host": "web.nxsha.app",
///       "path": "/embed/{type}/{id}",
///       "method": "GET",
///       "parameters": { "lang": "en", "sub": "1" },
///       "headers": {},
///       "cookies": [],
///       "body": null
///     }
///   ]
/// }
/// ```
/// Each provider entry is a request template: the optional `scheme`, `path`,
/// `method`, `parameters`, `headers`, `cookies` and `body` fields describe how
/// to build the HTTP request (see [MediaSourceProviderDefinition]). String
/// values may use the `{id}` and `{type}` placeholders, plus the
/// externally-controlled `{language}` and `{subtitles}` playback preferences.
abstract final class MediaSourceProviderFactory {
  const MediaSourceProviderFactory._();

  /// Default asset bundling the provider definitions. This is the source of
  /// truth for the available backends; edit that file to change them.
  static const String defaultAssetPath = 'assets/config/media_source_providers.json';

  /// Builds the provider from a raw JSON [source] string.
  static ConfigurableMediaSourceProvider createFromJson(
    String source, {
    MediaSourcePreferences? preferences,
    String playerServerUrl = const String.fromEnvironment('PLAYER_SERVER_URL'),
  }) => createFromMap(jsonDecode(source) as Map<String, dynamic>, preferences: preferences, playerServerUrl: playerServerUrl);

  /// Builds the provider from an already-decoded JSON [config] map.
  static ConfigurableMediaSourceProvider createFromMap(
    Map<String, dynamic> config, {
    MediaSourcePreferences? preferences,
    String playerServerUrl = const String.fromEnvironment('PLAYER_SERVER_URL'),
  }) {
    final resolvedPreferences = preferences ?? MediaSourcePreferences();
    final serverUrl = playerServerUrl.isEmpty ? null : Uri.parse(playerServerUrl);
    if (serverUrl != null &&
        (!['http', 'https'].contains(serverUrl.scheme) ||
            serverUrl.host.isEmpty ||
            serverUrl.userInfo.isNotEmpty ||
            serverUrl.hasQuery ||
            serverUrl.hasFragment ||
            !['', '/'].contains(serverUrl.path))) {
      throw const FormatException('PLAYER_SERVER_URL must be an HTTP(S) origin, for example http://localhost:3001.');
    }
    final rawProviders = config['providers'];
    if (rawProviders is! List || rawProviders.isEmpty) {
      throw const FormatException('Media source configuration must list at least one provider.');
    }

    final providers = rawProviders
        .map((raw) {
          final definition = Map<String, dynamic>.from(raw as Map);
          if (serverUrl != null && definition['path'] == '/player') {
            definition['scheme'] = serverUrl.scheme;
            definition['host'] = serverUrl.host;
            definition['port'] = serverUrl.hasPort ? serverUrl.port : null;
          }
          return JsonMediaSourceProvider(MediaSourceProviderDefinition.fromJson(definition), preferences: resolvedPreferences);
        })
        .toList(growable: false);

    final initialName = config['initialProvider'] as String?;
    final initial = initialName == null
        ? providers.first
        : providers.firstWhere(
            (provider) => provider.definition.name == initialName,
            orElse: () => throw FormatException('Unknown initialProvider "$initialName".'),
          );

    return ConfigurableMediaSourceProvider(providers: providers, preferences: resolvedPreferences, initialProvider: initial);
  }

  /// Loads the provider definition from a bundled JSON asset. Throws if the
  /// asset is missing or contains invalid configuration.
  static Future<ConfigurableMediaSourceProvider> createFromAsset([String assetPath = defaultAssetPath, MediaSourcePreferences? preferences]) async {
    final source = await rootBundle.loadString(assetPath);
    return createFromJson(source, preferences: preferences);
  }
}
