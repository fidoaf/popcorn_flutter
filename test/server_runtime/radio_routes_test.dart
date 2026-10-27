import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

const _stationId = '1cfb151d-a341-11e9-a787-52543be04c81';

void main() {
  test(
    'serves authenticated radio catalogue, station lookup, and playback',
    () async {
      final outbound = _FakeProviderHttpClient((uri) {
        if (uri.path.endsWith('/countrycodes')) {
          return _json([
            {'name': 'FR', 'stationcount': 5},
          ]);
        }
        if (uri.path.endsWith('/stations/search')) {
          return _json([_station()]);
        }
        if (uri.path.endsWith('/stations/byuuid/$_stationId')) {
          return _json([_station()]);
        }
        if (uri.path.endsWith('/json/url/$_stationId')) {
          return _json({
            'ok': true,
            'stationuuid': _stationId,
            'url': 'https://example.test/live.mp3',
          });
        }
        throw StateError('Unexpected request: $uri');
      });
      final radio = RadioCatalog(
        httpClient: outbound,
        discoverServers: () async => ['de1.api.radio-browser.info'],
      );
      final server = DartPlayerServer(
        providers: MediaProviderRegistry([const _Provider()]),
        apiTokens: {'radio-token'},
        radioCatalog: radio,
      );
      final client = HttpClient();
      try {
        await server.start();
        expect(
          (await _get(client, server, '/radio')).statusCode,
          HttpStatus.unauthorized,
        );

        final catalogue = await _get(
          client,
          server,
          '/radio?country=FR&q=Jazz',
          token: 'radio-token',
        );
        expect(catalogue.statusCode, HttpStatus.ok);
        final payload = jsonDecode(catalogue.body) as Map;
        expect((payload['stations'] as List).single['id'], _stationId);
        expect((payload['countries'] as List).single['code'], 'FR');

        final lookup = await _get(
          client,
          server,
          '/radio?station=$_stationId',
          token: 'radio-token',
        );
        expect(
          ((jsonDecode(lookup.body) as Map)['stations'] as List).single['id'],
          _stationId,
        );

        final playback = await _get(
          client,
          server,
          '/radio/play?station=$_stationId',
          token: 'radio-token',
        );
        expect(jsonDecode(playback.body), {
          'url': 'https://example.test/live.mp3',
        });

        final invalid = await _get(
          client,
          server,
          '/radio/play?station=invalid',
          token: 'radio-token',
        );
        expect(invalid.statusCode, HttpStatus.badRequest);
        expect(jsonDecode(invalid.body), {'error': 'invalid_radio_station'});
      } finally {
        client.close(force: true);
        await server.stop();
      }
    },
  );
}

Future<_HttpResult> _get(
  HttpClient client,
  DartPlayerServer server,
  String path, {
  String? token,
}) async {
  final request = await client.getUrl(server.baseUri.resolve(path));
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  final response = await request.close();
  return _HttpResult(
    response.statusCode,
    await utf8.decoder.bind(response).join(),
  );
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
  Future<ProviderHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async => respond(uri);
}

ProviderHttpResponse _json(Object value) =>
    ProviderHttpResponse(statusCode: 200, body: jsonEncode(value));

Map<String, Object?> _station() => {
  'stationuuid': _stationId,
  'name': 'Jazz FM',
  'url_resolved': 'https://example.test/jazz.mp3',
  'country': 'France',
  'countrycode': 'FR',
  'lastcheckok': 1,
};

final class _Provider implements MediaProvider {
  const _Provider();

  @override
  String get id => 'test';

  @override
  String get label => 'Test';
}
