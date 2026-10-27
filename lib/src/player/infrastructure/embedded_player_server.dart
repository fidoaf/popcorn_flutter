import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_browser_provider_adapter.dart';

final class EmbeddedPlayerServer {
  EmbeddedPlayerServer({required this.token, this.port = 0});

  static const _tokenKey = 'player.localServerToken';
  static const _legacyTokenKey = 'windows.localPlayerServerToken';

  final String token;
  final int port;
  DartPlayerServer? _runtime;
  DartIoProviderHttpClient? _httpClient;
  FlutterBrowserProviderAdapter? _browserAdapter;
  Uri? _serverUri;
  bool _stopped = false;

  String get serverUrl {
    final uri = _serverUri;
    if (uri == null) {
      throw StateError('Embedded player server has not started.');
    }
    return uri.toString();
  }

  static Future<String> loadToken(SharedPreferences preferences) async {
    final existing = preferences.getString(_tokenKey) ?? preferences.getString(_legacyTokenKey);
    if (existing != null && existing.isNotEmpty) {
      if (preferences.getString(_tokenKey) == null && !await preferences.setString(_tokenKey, existing)) {
        throw StateError('Unable to migrate the local server token.');
      }
      return existing;
    }
    final random = Random.secure();
    final token = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    if (!await preferences.setString(_tokenKey, token)) {
      throw StateError('Unable to save the local server token.');
    }
    return token;
  }

  Future<Uri> start() async {
    if (_stopped) {
      throw StateError('Embedded player server has already stopped.');
    }
    if (_runtime != null) {
      throw StateError('Embedded player server is already running.');
    }
    final httpClient = DartIoProviderHttpClient();
    final browserAdapter = FlutterBrowserProviderAdapter();
    DartPlayerServer? runtime;
    try {
      final rawConfig = jsonDecode(await rootBundle.loadString('assets/config/server_media_source_providers.json'));
      if (rawConfig is! Map) {
        throw const FormatException('Media source provider configuration must be an object.');
      }
      final config = Map<String, Object?>.from(rawConfig);
      final providers = CoreMediaProviderFactory.fromJson(
        config: config,
        httpClient: httpClient,
        postClient: httpClient,
        browserResponseCaptureClient: browserAdapter,
        sameOriginBrowserFetchClient: browserAdapter,
      );
      runtime = DartPlayerServer(
        providers: providers,
        apiTokens: {token},
        host: '127.0.0.1',
        port: port,
        providerHttpClient: httpClient,
        streamingHttpClient: httpClient,
      );
      final uri = await runtime.start();
      _runtime = runtime;
      _httpClient = httpClient;
      _browserAdapter = browserAdapter;
      _serverUri = uri;
      return uri;
    } on Object {
      await runtime?.stop();
      await browserAdapter.close();
      httpClient.close(force: true);
      rethrow;
    }
  }

  Future<void> stop() async {
    _stopped = true;
    final runtime = _runtime;
    final httpClient = _httpClient;
    final browserAdapter = _browserAdapter;
    _runtime = null;
    _httpClient = null;
    _browserAdapter = null;
    _serverUri = null;
    await runtime?.stop();
    await browserAdapter?.close();
    httpClient?.close(force: true);
  }
}
