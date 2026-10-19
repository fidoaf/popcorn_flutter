import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/radio/radio_controller.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';

void main() {
  final data = {
    'id': '1cfb151d-a341-11e9-a787-52543be04c81',
    'name': 'Ràdio música',
    'url': 'https://example.com/radio.mp3',
    'logo': 'https://example.com/logo.png',
    'country': 'España',
    'languages': ['català'],
    'tags': ['música'],
    'codec': 'MP3',
    'bitrate': 128,
  };

  test('parses stations and rejects unsafe stream and logo URLs', () {
    final station = RadioStation.fromJson(data);
    expect(station.name, 'Ràdio música');
    expect(station.bitrate, 128);
    expect(station.logoUrl, Uri.https('example.com', '/logo.png'));
    expect(RadioStation.fromJson({...data, 'logo': 'file:///logo.png'}).logoUrl, isNull);
    for (final url in ['file:///stream', 'https://user:pass@example.com/stream', 'invalid']) {
      expect(() => RadioStation.fromJson({...data, 'url': url}), throwsFormatException);
    }
  });

  test('loads UTF-8 metadata with bearer auth and uses exact station lookup and playback paths', () async {
    final requests = <Uri>[];
    final controller = RadioController(
      endpoint: Uri.https('server.example', '/radio'),
      serverToken: 'test-token',
      client: MockClient((request) async {
        requests.add(request.url);
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.queryParameters.containsKey('token'), isFalse);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/play')
                ? {'url': data['url']}
                : {
                    'stations': [data],
                  },
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.stations.single.name, 'Ràdio música');
    expect(controller.stations.single.country, 'España');
    expect(controller.hasError, isFalse);
    await controller.load(stationId: data['id'] as String);
    expect(requests.last.queryParameters['station'], data['id']);
    final stream = await controller.startPlayback(data['id'] as String);
    expect(stream, Uri.parse(data['url'] as String));
    expect(requests.last.path, '/radio/play');
  });

  test('shows errors for invalid responses and allows retry', () async {
    for (final invalid in [http.Response('', 503), http.Response('{"stations":{}}', 200), http.Response('{"stations":[{}]}', 200)]) {
      var fail = true;
      final controller = RadioController(serverToken: '', client: MockClient((_) async => fail ? invalid : http.Response('{"stations":[]}', 200)));
      await controller.load();
      expect(controller.hasError, isTrue);
      expect(controller.isLoading, isFalse);
      fail = false;
      await controller.load();
      expect(controller.hasError, isFalse);
      expect(controller.stations, isEmpty);
      controller.dispose();
    }
  });

  test('country selection persists for retries, clears, and does not affect exact station lookup', () async {
    final requests = <Uri>[];
    var failed = false;
    final controller = RadioController(
      serverToken: '',
      client: MockClient((request) async {
        requests.add(request.url);
        return failed
            ? http.Response('', 502)
            : http.Response(
                jsonEncode({
                  'stations': [data],
                  'countries': [
                    {
                      'code': 'ES',
                      'name': 'Spain',
                      'flag': '🇪🇸',
                      'names': {'es': 'España', 'ca': 'Espanya'},
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.selectedCountry, isNull);
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
    expect(controller.countries.single.names['ca'], 'Espanya');
    await controller.selectCountry('ES');
    expect(requests.last.queryParameters['country'], 'ES');
    failed = true;
    await controller.load();
    expect(controller.hasError, isTrue);
    expect(controller.countries, hasLength(1));
    expect(controller.selectedCountry, 'ES');
    failed = false;
    await controller.load();
    expect(requests.last.queryParameters['country'], 'ES');
    await controller.load(stationId: data['id'] as String);
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
    expect(requests.last.queryParameters['station'], data['id']);
    await controller.selectCountry(null);
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
  });

  test('rejects invalid playback responses', () async {
    final controller = RadioController(serverToken: '', client: MockClient((_) async => http.Response('{"url":"file:///audio"}', 200)));
    addTearDown(controller.dispose);
    await expectLater(controller.startPlayback('example'), throwsFormatException);
  });

  test('ignores stale responses and completion after disposal', () async {
    final pending = <Completer<http.Response>>[];
    final controller = RadioController(
      serverToken: '',
      client: MockClient((_) {
        final completion = Completer<http.Response>();
        pending.add(completion);
        return completion.future;
      }),
    );
    final first = controller.selectCountry('FR');
    final second = controller.selectCountry('ES');
    await Future<void>.delayed(Duration.zero);
    pending[1].complete(http.Response('{"stations":[]}', 200));
    await second;
    pending[0].complete(http.Response('', 503));
    await first;
    expect(controller.hasError, isFalse);
    expect(controller.selectedCountry, 'ES');
    final last = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    pending.last.complete(http.Response('{"stations":[]}', 200));
    await last;
  });
}
