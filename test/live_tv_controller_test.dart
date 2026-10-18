import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_controller.dart';

void main() {
  test('channel search sends trimmed q, retains it on retry and clears it', () async {
    final requests = <Uri>[];
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"channels":[]}', 200);
      }),
    );
    addTearDown(controller.dispose);
    await controller.search('  News  ');
    expect(requests.last.queryParameters['q'], 'News');
    await controller.load();
    expect(requests.last.queryParameters['q'], 'News');
    await controller.search('');
    expect(requests.last.queryParameters.containsKey('q'), isFalse);
  });

  test('loads channel metadata and stream headers from the catalogue endpoint', () async {
    final controller = LiveTvController(
      endpoint: Uri.parse('https://example.com/live-tv'),
      serverToken: 'test-server-token',
      client: MockClient((request) async {
        expect(request.url.path, '/live-tv');
        expect(request.headers['Authorization'], 'Bearer test-server-token');
        expect(request.headers['Accept'], 'application/json');
        expect(request.url.queryParameters.containsKey('token'), isFalse);
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 'channel.us',
                'name': 'Example News',
                'url': 'https://example.com/live.m3u8',
                'country': 'US',
                'languages': ['eng'],
                'categories': ['news'],
                'logo': 'https://example.com/logo.png',
                'logoFormat': 'PNG',
                'headers': {'Referer': 'https://example.com/'},
              },
            ],
          }),
          200,
        );
      }),
    );

    await controller.load();

    expect(controller.hasError, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.channels, hasLength(1));
    expect(controller.channels.single.name, 'Example News');
    expect(controller.channels.single.streamUrl, Uri.parse('https://example.com/live.m3u8'));
    expect(controller.channels.single.headers['Referer'], 'https://example.com/');
    expect(controller.channels.single.logoUrl, Uri.parse('https://example.com/logo.png'));
    expect(controller.channels.single.hasSvgLogo, isFalse);
    controller.dispose();
  });

  test('omits authorization when no server token is configured', () async {
    final controller = LiveTvController(
      endpoint: Uri.parse('https://example.com/live-tv'),
      serverToken: '',
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{"channels":[]}', 200);
      }),
    );
    await controller.load();
    expect(controller.hasError, isFalse);
    controller.dispose();
  });

  test('exposes an unavailable state when the catalogue endpoint fails', () async {
    final controller = LiveTvController(
      endpoint: Uri.parse('https://example.com/live-tv'),
      client: MockClient((_) async => http.Response('unavailable', 502)),
    );

    await controller.load();

    expect(controller.hasError, isTrue);
    expect(controller.isLoading, isFalse);
    expect(controller.channels, isEmpty);
    controller.dispose();
  });

  test('starts with no country and sends or clears the country filter', () async {
    final requests = <Uri>[];
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode({
            'channels': [
              {'id': 'channel.fr', 'name': 'French TV', 'country': 'FR', 'url': 'https://example.com/live.m3u8'},
            ],
            'countries': [
              {'code': 'FR', 'name': 'France', 'flag': '🇫🇷'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(controller.dispose);
    expect(controller.selectedCountry, isNull);
    await controller.load();
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
    expect(controller.countries.single.name, 'France');
    expect(controller.countries.single.flag, '🇫🇷');
    await controller.selectCountry('FR');
    expect(controller.selectedCountry, 'FR');
    expect(requests.last.queryParameters['country'], 'FR');
    await controller.load();
    expect(requests.last.queryParameters['country'], 'FR');
    await controller.selectCountry(null);
    expect(controller.selectedCountry, isNull);
    expect(requests.last.queryParameters.containsKey('country'), isFalse);
    await controller.load(channelId: 'channel.fr');
    expect(requests.last.queryParameters['channel'], 'channel.fr');
  });

  test('rapid country changes ignore responses from an older selection', () async {
    final first = Completer<http.Response>();
    final second = Completer<http.Response>();
    final controller = LiveTvController(
      serverToken: '',
      client: MockClient((request) => request.url.queryParameters['country'] == 'FR' ? first.future : second.future),
    );
    addTearDown(controller.dispose);
    final france = controller.selectCountry('FR');
    final usa = controller.selectCountry('US');
    second.complete(http.Response('{"channels":[{"id":"us","name":"US TV","country":"US","url":"https://example.com/live"}]}', 200));
    await usa;
    first.complete(http.Response('{"channels":[]}', 200));
    await france;
    expect(controller.selectedCountry, 'US');
    expect(controller.channels.single.id, 'us');
    expect(controller.isLoading, isFalse);
  });
}
