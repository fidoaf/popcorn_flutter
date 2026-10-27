import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  test('serves authenticated live-TV catalog filters and metadata', () async {
    final liveTv = LiveTvCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        if (uri.path.endsWith('/channels.json')) {
          return _json([
            {'id': 'Example.fr', 'name': 'Example TV', 'country': 'FR'},
            {'id': 'Other.us', 'name': 'Other TV', 'country': 'US'},
          ]);
        }
        if (uri.path.endsWith('/streams.json')) {
          return _json([
            {'channel': 'Example.fr', 'url': 'https://example.test/live.m3u8'},
            {'channel': 'Other.us', 'url': 'https://other.test/live.m3u8'},
          ]);
        }
        return _json(<Object>[]);
      }),
    );
    final server = DartPlayerServer(providers: MediaProviderRegistry([const _Provider()]), apiTokens: {'live-tv-token'}, liveTvCatalog: liveTv);
    final client = HttpClient();
    try {
      await server.start();
      expect((await _get(client, server, '/live-tv')).statusCode, HttpStatus.unauthorized);

      final response = await _get(client, server, '/live-tv?country=FR&q=Example', token: 'live-tv-token');
      expect(response.statusCode, HttpStatus.ok);
      final json = jsonDecode(response.body) as Map;
      expect((json['channels'] as List).single['id'], 'Example.fr');
      expect((json['countries'] as List).map((country) => country['code']), ['FR', 'US']);
    } finally {
      client.close(force: true);
      await server.stop();
    }
  });
}

Future<_HttpResult> _get(HttpClient client, DartPlayerServer server, String path, {String? token}) async {
  final request = await client.getUrl(server.baseUri.resolve(path));
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  final response = await request.close();
  return _HttpResult(response.statusCode, await utf8.decoder.bind(response).join());
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

final class _FakeProviderHttpClient implements ProviderHttpClient {
  _FakeProviderHttpClient(this.respond);

  final ProviderHttpResponse Function(Uri uri) respond;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async => respond(uri);
}

ProviderHttpResponse _json(Object value) => ProviderHttpResponse(statusCode: 200, body: jsonEncode(value));

final class _Provider implements MediaProvider {
  const _Provider();

  @override
  String get id => 'test';

  @override
  String get label => 'Test';
}
