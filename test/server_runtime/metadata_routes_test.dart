import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  test('serves authenticated IntroDB and JustWatch metadata routes', () async {
    final context = base64.encode(
      utf8.encode(
        jsonEncode({
          'data': [
            {
              'data': {'providerId': 10},
            },
          ],
        }),
      ),
    );
    final clickout = Uri.https('click.justwatch.com', '/a', {
      'cx': context,
      'r': 'https://example.test/watch',
    });
    final outbound = _FakeProviderHttpClient((uri) {
      if (uri.host == 'api.theintrodb.org') {
        return _json({
          'intro': [
            {'start_ms': 1000, 'end_ms': 2000},
          ],
          'credits': [],
        });
      }
      if (uri.path == '/us/search') {
        return _ok('<a href="/us/movie/example">Example (2024)</a>');
      }
      if (uri.path == '/us/movie/example') {
        return _ok(
          '<a href="${clickout.toString().replaceAll('&', '&amp;')}">Offer</a>',
        );
      }
      throw StateError('Unexpected outbound request: $uri');
    });
    final server = DartPlayerServer(
      providers: MediaProviderRegistry([const _Provider()]),
      apiTokens: {'route-token'},
      providerHttpClient: outbound,
    );
    final client = HttpClient();
    try {
      await server.start();
      final unauthorized = await _get(
        client,
        server,
        '/introdb?type=movie&id=42&duration_ms=60000',
      );
      expect(unauthorized.statusCode, HttpStatus.unauthorized);
      expect(outbound.calls, isEmpty);

      final intro = await _get(
        client,
        server,
        '/introdb?type=movie&id=42&duration_ms=60000',
        token: 'route-token',
      );
      expect(intro.statusCode, HttpStatus.ok);
      expect((jsonDecode(intro.body) as Map)['intro'], hasLength(1));

      final offers = await _get(
        client,
        server,
        '/watch-providers?type=movie&title=Example&year=2024&region=US',
        token: 'route-token',
      );
      expect(offers.statusCode, HttpStatus.ok);
      expect(jsonDecode(offers.body), {'10': clickout.toString()});
      expect(offers.headers.value('access-control-allow-origin'), '*');

      final invalid = await _get(
        client,
        server,
        '/watch-providers?type=invalid&title=Example&region=US',
        token: 'route-token',
      );
      expect(invalid.statusCode, HttpStatus.badRequest);
      expect(jsonDecode(invalid.body), {
        'error': 'Provide a valid media type, title and two-letter region',
      });
    } finally {
      client.close(force: true);
      await server.stop();
    }
  });
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
    response.headers,
    await utf8.decoder.bind(response).join(),
  );
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

final class _FakeProviderHttpClient implements ProviderHttpClient {
  _FakeProviderHttpClient(this.respond);

  final ProviderHttpResponse Function(Uri uri) respond;
  final calls = <Uri>[];

  @override
  Future<ProviderHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    calls.add(uri);
    return respond(uri);
  }
}

ProviderHttpResponse _ok(String body) =>
    ProviderHttpResponse(statusCode: 200, body: body);

ProviderHttpResponse _json(Object value) => _ok(jsonEncode(value));

final class _Provider implements MediaProvider {
  const _Provider();

  @override
  String get id => 'test';

  @override
  String get label => 'Test';
}
