import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('IntroDB maps movie and TV IDs into its fixed API request', () async {
    for (final id in ['1399', 'tt0944947']) {
      final client = _FakeProviderHttpClient((uri) {
        expect(uri.origin, 'https://api.theintrodb.org');
        expect(uri.path, '/v4/media');
        expect(
          uri.queryParameters[id.startsWith('tt') ? 'imdb_id' : 'tmdb_id'],
          id,
        );
        expect(uri.queryParameters['season'], '2');
        expect(uri.queryParameters['episode'], '3');
        expect(uri.queryParameters['duration_ms'], '2700000');
        expect(uri.queryParameters.containsKey('type'), isFalse);
        return _json({'tvdb_id': 121361, 'intro': []});
      });
      final result = await IntroDbClient(httpClient: client).fetch({
        'id': id,
        'type': 'tv',
        'season': '2',
        'episode': '3',
        'duration_ms': '2700000',
      });
      expect(result['tvdb_id'], 121361);
    }
  });

  test(
    'IntroDB maps missing data and rejects invalid media before fetching',
    () async {
      final missing = IntroDbClient(
        httpClient: _FakeProviderHttpClient(
          (_) => ProviderHttpResponse(statusCode: 404, body: ''),
        ),
      );
      expect(
        await missing.fetch({
          'id': '42',
          'type': 'movie',
          'duration_ms': '60000',
        }),
        {'intro': [], 'credits': []},
      );

      final unused = _FakeProviderHttpClient(
        (_) => throw StateError('Unexpected request'),
      );
      final client = IntroDbClient(httpClient: unused);
      for (final query in [
        {'id': '42', 'type': 'movie', 'duration_ms': 'NaN'},
        {
          'id': '42',
          'type': 'tv',
          'season': '1',
          'episode': '0',
          'duration_ms': '60000',
        },
        {'id': 'https://example.test', 'type': 'movie', 'duration_ms': '60000'},
      ]) {
        await expectLater(
          client.fetch(query),
          throwsA(isA<InvalidMediaRequest>()),
        );
      }
      expect(unused.calls, isEmpty);
    },
  );

  test('JustWatch selects regional title pages and extracts provider clickouts', () async {
    final context = {
      'data': [
        {
          'schema': 'clickout_context',
          'data': {'providerId': 10, 'monetizationType': 'RENT'},
        },
        {
          'schema': 'title_context',
          'data': {'titleId': 1265001, 'objectType': 'movie'},
        },
      ],
    };
    final clickout = Uri.https('click.justwatch.com', '/a', {
      'cx': base64.encode(utf8.encode(jsonEncode(context))),
      'r': 'https://example.test/title',
    });
    final requests = <Uri>[];
    final service = JustWatchProviderLinks(
      httpClient: _FakeProviderHttpClient((uri) {
        requests.add(uri);
        if (requests.length == 1) {
          return _ok(
            '<a href="/es/pelicula/spider-man-un-nuevo-dia">Spider-Man: Un nuevo día (2026)</a>',
          );
        }
        return _ok(
          '<a href="${clickout.toString().replaceAll('&', '&amp;')}">Amazon Video</a>',
        );
      }),
    );

    final links = await service.resolve(
      type: 'movie',
      title: 'Spider-Man: Brand New Day',
      year: '2026',
      region: 'es',
    );

    expect(links, {'10': clickout.toString()});
    expect(requests[0].path, '/es/buscar');
    expect(requests[0].queryParameters['q'], 'Spider-Man: Brand New Day 2026');
    expect(requests[1].path, '/es/pelicula/spider-man-un-nuevo-dia');
    expect(requests.length, 2);
  });

  test('JustWatch maps GB to UK and validates search inputs', () async {
    final requests = <Uri>[];
    final service = JustWatchProviderLinks(
      httpClient: _FakeProviderHttpClient((uri) {
        requests.add(uri);
        return _ok(
          requests.length == 1
              ? '<a href="https://www.justwatch.com/uk/tv-series/solar-opposites">Solar Opposites (2020)</a>'
              : '<html>No offers</html>',
        );
      }),
    );
    expect(
      await service.resolve(
        type: 'tv',
        title: 'Solar Opposites',
        year: '2020',
        region: 'GB',
      ),
      isEmpty,
    );
    expect(requests.first.path, '/uk/search');
    expect(requests.last.path, '/uk/tv-series/solar-opposites');

    for (final (type, title, region) in [
      (null, 'Title', 'US'),
      ('movie', '', 'US'),
      ('movie', 'Title', 'USA'),
      ('tv', 'x' * 201, 'US'),
    ]) {
      await expectLater(
        service.resolve(type: type, title: title, year: '', region: region),
        throwsA(isA<InvalidMediaRequest>()),
      );
    }
  });
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
