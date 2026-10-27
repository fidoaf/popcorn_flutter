import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('normalizes channels, selects safe streams, and caches the joined catalogue', () async {
    var now = DateTime.utc(2026);
    var calls = 0;
    final catalog = LiveTvCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        calls++;
        if (uri.path.endsWith('/channels.json')) {
          return _json([
            {
              'id': 'beta.us',
              'name': 'Beta TV',
              'country': 'US',
              'languages': ['eng'],
              'categories': ['news'],
              'website': 'https://beta.test',
            },
            {'id': 'alpha.us', 'name': 'Alpha TV', 'country': 'US', 'website': 'javascript:alert(1)'},
            {'id': 'missing.us', 'name': 'No Stream'},
          ]);
        }
        if (uri.path.endsWith('/streams.json')) {
          return _json([
            {'channel': 'beta.us', 'url': 'https://beta.test/live.m3u8', 'http_referrer': 'https://beta.test/', 'user_agent': 'Test player'},
            {'channel': 'alpha.us', 'url': 'https://alpha.test/live.m3u8'},
            {'channel': 'alpha.us', 'url': 'https://alpha.test/duplicate.m3u8'},
            {'channel': 'missing.us', 'url': 'file:///private/stream.m3u8'},
          ]);
        }
        if (uri.path.endsWith('/logos.json')) {
          return _json([
            {'channel': 'beta.us', 'in_use': true, 'format': 'PNG', 'url': 'https://beta.test/logo.png'},
            {'channel': 'alpha.us', 'url': 'javascript:alert(1)'},
          ]);
        }
        return _json(<Object>[]);
      }),
      clock: () => now,
    );

    final first = await catalog.getChannels();
    expect(first.map((channel) => channel['name']), ['Alpha TV', 'Beta TV']);
    expect(first.first['logo'], isNull);
    expect(first[1]['url'], 'https://beta.test/live.m3u8');
    expect(first[1]['headers'], {'Referer': 'https://beta.test/', 'User-Agent': 'Test player'});
    expect(first[1]['logoFormat'], 'PNG');
    expect(calls, 7);
    await catalog.getChannels();
    expect(calls, 7);
    now = now.add(const Duration(hours: 6, seconds: 1));
    await catalog.getChannels();
    expect(calls, 14);
  });

  test('matches logo and broadcast metadata by selected feed', () async {
    final catalog = LiveTvCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        if (uri.path.endsWith('/channels.json')) {
          return _json([
            {'id': 'Example.fr', 'name': 'Example TV', 'country': 'FR'},
          ]);
        }
        if (uri.path.endsWith('/streams.json')) {
          return _json([
            {'channel': 'Example.fr', 'feed': 'Paris', 'url': 'https://example.test/live.m3u8'},
          ]);
        }
        if (uri.path.endsWith('/logos.json')) {
          return _json([
            {'channel': 'Example.fr', 'feed': 'Other', 'in_use': true, 'url': 'https://example.test/wrong.png'},
            {
              'channel': 'Example.fr',
              'feed': 'Paris',
              'in_use': true,
              'tags': ['horizontal', 'white'],
              'format': 'SVG',
              'url': 'https://example.test/right.svg',
            },
          ]);
        }
        if (uri.path.endsWith('/feeds.json')) {
          return _json([
            {
              'channel': 'Example.fr',
              'id': 'Paris',
              'broadcast_area': ['c/FR', 'r/EUR', 'invalid'],
            },
          ]);
        }
        if (uri.path.endsWith('/regions.json')) {
          return _json([
            {'code': 'EUR', 'name': 'Europe'},
          ]);
        }
        return _json(<Object>[]);
      }),
    );

    final channel = await catalog.getChannel('Example.fr');
    expect(channel?['logo'], 'https://example.test/right.svg');
    expect(channel?['logoFormat'], 'SVG');
    expect(channel?['countryNames'], {'en': 'France', 'es': 'Francia', 'ca': 'França'});
    expect(channel?['broadcastAreas'], [
      {
        'code': 'c/FR',
        'name': 'France',
        'names': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
      },
      {'code': 'r/EUR', 'name': 'Europe', 'names': {}},
    ]);
    expect((await catalog.getCatalogue(channelId: 'Example.fr'))['channels'], hasLength(1));
  });

  test('filters by country and query and does not cache failed source data', () async {
    var failed = true;
    final catalog = LiveTvCatalog(
      httpClient: _FakeProviderHttpClient((uri) {
        if (uri.path.endsWith('/channels.json')) {
          if (failed) return _json({'invalid': true});
          return _json([
            {'id': 'Alpha.us', 'name': 'Alpha News', 'country': 'US'},
            {'id': 'Beta.fr', 'name': 'Beta News', 'country': 'FR'},
          ]);
        }
        if (uri.path.endsWith('/streams.json')) {
          return _json([
            {'channel': 'Alpha.us', 'url': 'https://example.test/alpha.m3u8'},
            {'channel': 'Beta.fr', 'url': 'https://example.test/beta.m3u8'},
          ]);
        }
        return _json(<Object>[]);
      }),
    );

    await expectLater(catalog.getCatalogue(), throwsA(isA<FormatException>()));
    failed = false;
    final filtered = await catalog.getCatalogue(country: 'FR', query: 'beta');
    expect((filtered['channels'] as List).map((entry) => entry['id']), ['Beta.fr']);
    expect((filtered['countries'] as List).map((entry) => entry['code']), ['FR', 'US']);
    expect((await catalog.getCatalogue(query: 'no match'))['channels'], isEmpty);
  });
}

final class _FakeProviderHttpClient implements ProviderHttpClient {
  _FakeProviderHttpClient(this.respond);

  final ProviderHttpResponse Function(Uri uri) respond;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async => respond(uri);
}

ProviderHttpResponse _json(Object value) => ProviderHttpResponse(statusCode: 200, body: jsonEncode(value));
