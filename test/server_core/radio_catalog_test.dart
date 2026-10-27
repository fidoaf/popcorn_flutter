import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

const _stationId = '1cfb151d-a341-11e9-a787-52543be04c81';

void main() {
  test(
    'normalizes, deduplicates, and caches available stations and countries',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final catalog = RadioCatalog(
        httpClient: _FakeProviderHttpClient((uri) {
          calls++;
          if (uri.path.endsWith('/countrycodes')) {
            return _json([
              {'name': 'FR', 'stationcount': 12},
            ]);
          }
          return _json([
            _station(),
            _station(),
            {..._station(), 'lastcheckok': 0},
            {..._station(), 'stationuuid': 'invalid'},
            {
              ..._station(),
              'stationuuid': '00000000-0000-0000-0000-000000000001',
              'url': 'file:///audio',
              'url_resolved': null,
            },
          ]);
        }),
        discoverServers: () async => ['de1.api.radio-browser.info'],
        clock: () => now,
      );

      final result = await catalog.getCatalogue();
      expect(result['stations'], [
        {
          'id': _stationId,
          'name': 'France Info',
          'url': 'https://example.com/live.mp3',
          'logo': 'https://example.com/logo.png',
          'website': 'https://example.com/',
          'country': 'France',
          'countryCode': 'FR',
          'languages': ['french', 'english'],
          'tags': ['news', 'talk'],
          'codec': 'MP3',
          'bitrate': 128,
        },
      ]);
      expect((result['countries'] as List).single, {
        'code': 'FR',
        'name': 'France',
        'names': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
        'flag': '🇫🇷',
      });
      expect(calls, 2);
      await catalog.getCatalogue();
      expect(calls, 2);
      now = now.add(const Duration(hours: 1, seconds: 1));
      await catalog.getCatalogue();
      expect(calls, 4);
    },
  );

  test(
    'retries another discovered mirror after network and status failures',
    () async {
      final hosts = <String>[];
      final catalog = RadioCatalog(
        httpClient: _FakeProviderHttpClient((uri) {
          hosts.add(uri.host);
          if (uri.host == 'de1.api.radio-browser.info') {
            return ProviderHttpResponse(statusCode: 503, body: '');
          }
          if (uri.path.endsWith('/countrycodes')) {
            return _json(<Object>[]);
          }
          return _json([_station()]);
        }),
        discoverServers: () async => [
          'de1.api.radio-browser.info',
          'de2.api.radio-browser.info',
        ],
      );

      final result = await catalog.getCatalogue();
      expect((result['stations'] as List).length, 1);
      expect(hosts, [
        'de1.api.radio-browser.info',
        'de2.api.radio-browser.info',
        'de1.api.radio-browser.info',
        'de2.api.radio-browser.info',
      ]);
    },
  );

  test('looks up stations and starts playback only for safe URLs', () async {
    final paths = <String>[];
    final catalog = RadioCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        paths.add(uri.path);
        if (uri.path.startsWith('/json/url/')) {
          return _json({
            'ok': true,
            'stationuuid': _stationId,
            'url': 'https://example.com/play.mp3',
          });
        }
        return _json([_station()]);
      }),
      discoverServers: () async => ['de1.api.radio-browser.info'],
    );

    expect((await catalog.getStation(_stationId))?['id'], _stationId);
    expect(await catalog.startPlayback(_stationId), {
      'url': 'https://example.com/play.mp3',
    });
    expect(paths, [
      '/json/stations/byuuid/$_stationId',
      '/json/url/$_stationId',
    ]);

    for (final invalid in ['invalid', '../url', '']) {
      await expectLater(
        catalog.getStation(invalid),
        throwsA(
          isA<RadioCatalogException>().having(
            (error) => error.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
      await expectLater(
        catalog.startPlayback(invalid),
        throwsA(
          isA<RadioCatalogException>().having(
            (error) => error.statusCode,
            'statusCode',
            400,
          ),
        ),
      );
    }
  });

  test('rejects invalid radio country and unsafe playback URL', () async {
    final catalog = RadioCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        if (uri.path.startsWith('/json/url/')) {
          return _json({
            'ok': true,
            'stationuuid': _stationId,
            'url': 'file:///private/audio',
          });
        }
        return _json(<Object>[]);
      }),
      discoverServers: () async => ['de1.api.radio-browser.info'],
    );

    await expectLater(
      catalog.getCatalogue(country: 'Spain'),
      throwsA(
        isA<RadioCatalogException>().having(
          (error) => error.code,
          'code',
          'invalid_radio_country',
        ),
      ),
    );
    await expectLater(
      catalog.startPlayback(_stationId),
      throwsA(isA<RadioCatalogException>()),
    );
  });
}

Map<String, Object?> _station() => {
  'stationuuid': _stationId,
  'name': ' France Info ',
  'url': 'https://example.com/fallback.mp3',
  'url_resolved': 'https://example.com/live.mp3',
  'favicon': 'https://example.com/logo.png',
  'homepage': 'https://example.com',
  'country': 'France',
  'countrycode': 'FR',
  'language': 'french, english',
  'tags': 'news, talk',
  'codec': 'MP3',
  'bitrate': 128,
  'lastcheckok': 1,
};

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
