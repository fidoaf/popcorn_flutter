import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/infrastructure/embedded_player_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a stable token and serves the bundled Dart player API on loopback', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final token = await EmbeddedPlayerServer.loadToken(preferences);
    expect(base64Url.decode(token), hasLength(32));
    expect(await EmbeddedPlayerServer.loadToken(preferences), token);

    final server = EmbeddedPlayerServer(token: token);
    final client = HttpClient();
    try {
      final address = await server.start();
      expect(address.host, '127.0.0.1');

      final healthRequest = await client.getUrl(address.resolve('/health'));
      final health = await healthRequest.close();
      expect(health.statusCode, HttpStatus.ok);
      expect(await utf8.decoder.bind(health).join(), 'ok');

      final providersRequest = await client.getUrl(address.resolve('/providers'));
      providersRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final providers = await providersRequest.close();
      expect(providers.statusCode, HttpStatus.ok);
      final body = jsonDecode(await utf8.decoder.bind(providers).join()) as Map;
      expect(body['defaultProvider'], 'vidsrcbuzz');
      expect((body['providers'] as List).map((provider) => provider['id']), contains('nxsha'));
      expect((body['providers'] as List).map((provider) => provider['id']), contains('cinesrc'));
    } finally {
      client.close(force: true);
      await server.stop();
      HttpOverrides.global = previousOverrides;
    }
  });

  test('migrates a token saved by the previous Windows local server', () async {
    SharedPreferences.setMockInitialValues({'windows.localPlayerServerToken': 'previous-install-token'});
    final preferences = await SharedPreferences.getInstance();

    expect(await EmbeddedPlayerServer.loadToken(preferences), 'previous-install-token');
    expect(preferences.getString('player.localServerToken'), 'previous-install-token');
  });
}
