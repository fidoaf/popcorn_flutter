import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

const _movie = MediaRequest(providerId: 'nxsha', type: 'movie', id: '969681', lang: 'en', sub: '1', season: '0', episode: '0');

void main() {
  test('builds media payloads and lists unique direct HLS sources only', () async {
    final calls = <Uri>[];
    final sourcePayloads = <Map<String, Object?>>[];
    const hlsUrl = 'https://wts.itsnitrox.tech/nitro/example-token/master.m3u8';
    final client = _FakeHttpClient((uri, headers) {
      calls.add(uri);
      if (uri.path == '/api/servers') {
        return _json({
          '_hash': encodeNxshaData({
            'servers': [
              {'name': 'App-only', 'scraper': 'app-only', 'web_support': false},
              {'name': 'ShowNitro', 'scraper': 'showbox-online', 'web_support': true},
              {'name': 'Embed server', 'scraper': 'embed-only', 'web_support': true},
              {'name': 'Nitro server', 'scraper': 'nitro', 'web_support': true},
              {'name': 'Duplicate server', 'scraper': 'second-nitro', 'web_support': true},
            ],
          }),
        });
      }
      if (uri.path == '/api/sources') {
        final payload = decodeNxshaData(uri.queryParameters['q']);
        sourcePayloads.add(payload!);
        if (payload['provider'] == 'embed-only') {
          return _json({
            '_hash': encodeNxshaData({
              'sources': [
                {'url': 'https://embed.example/player', 'type': 'embed', 'isEmbed': true},
              ],
            }),
          });
        }
        return _json({
          '_hash': encodeNxshaData({
            'sources': [
              {'url': hlsUrl, 'type': 'm3u8', 'quality': '1080p', 'language': 'English'},
            ],
          }),
        });
      }
      throw StateError('Unexpected Nxsha request: $uri');
    });
    final provider = NxshaProvider(httpClient: client);

    final listing = await provider.listSources(_movie);

    expect(calls.first.origin, 'https://web.nxsha.app');
    expect(calls.first.path, '/api/servers');
    expect(sourcePayloads.map((payload) => payload['provider']).toSet(), {'embed-only', 'nitro', 'second-nitro'});
    expect(sourcePayloads.every((payload) => payload['tmdbId'] == 969681 && payload['ex_lang'] == true), isTrue);
    expect(listing.sources, hasLength(1));
    expect(listing.sources.single.ref, {'url': hlsUrl});
    expect(listing.sources.single.name, 'Nitro server · 1080p');
    expect(listing.sources.single.language, 'English');

    final selected = SourceReference(
      source: {
        'ref': {'url': hlsUrl},
      },
      providerId: provider.id,
      mediaKey: 'movie:969681:0:0:en:1',
    );
    final stream = await provider.extract(_movie, selectedSource: selected);
    expect(stream.uri.toString(), hlsUrl);
    expect(stream.type, 'hls');
  });

  test('falls back to browser transport and resolves IMDb IDs before catalog lookup', () async {
    final browserCalls = <Uri>[];
    final direct = _FakeHttpClient((uri, _) => throw StateError('direct fetch failed'));
    final browser = _FakeBrowserFetchClient((uri, _) {
      browserCalls.add(uri);
      if (uri.path == '/embed/movie/tt22084616') {
        return _ok(r'page-props:{"tmdbId":969681,"imdb_id":"$undefined"}');
      }
      if (uri.path == '/api/servers') {
        return _json({
          '_hash': encodeNxshaData({'servers': []}),
        });
      }
      throw StateError('Unexpected browser request: $uri');
    });
    final provider = NxshaProvider(httpClient: direct, browserFetchClient: browser);
    const media = MediaRequest(providerId: 'nxsha', type: 'movie', id: 'tt22084616', lang: 'en', sub: '1', season: '0', episode: '0');

    expect(await provider.listServers(media), isEmpty);
    expect(browserCalls.map((uri) => uri.path), ['/embed/movie/tt22084616', '/api/servers']);
    final payload = decodeNxshaData(browserCalls.last.queryParameters['q']);
    expect(payload, {'tmdbId': 969681, 'imdb_id': 'tt22084616', 'type': 'movie', 'season': 1, 'episode': 1});
  });

  test('lists subtitle tracks and converts approved SRT downloads to WebVTT', () async {
    const subtitleUrl = 'https://dl.opensubtitles.org/en/download/src-api/vrf-test/file/123';
    final calls = <Uri>[];
    final client = _FakeHttpClient((uri, headers) {
      calls.add(uri);
      if (uri.path == '/api/subtitles') {
        final payload = decodeNxshaData(uri.queryParameters['q']);
        expect(payload?['tmdbId'], 969681);
        return _json({
          '_hash': encodeNxshaData({
            'subtitles': [
              {'title': 'English', 'language': 'en', 'uri': subtitleUrl},
            ],
          }),
        });
      }
      if (uri.toString() == subtitleUrl) {
        expect(headers['Referer'], 'https://web.nxsha.app/');
        expect(headers['Accept'], contains('text/vtt'));
        return _ok('1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n', headers: {'Content-Type': 'application/x-subrip'});
      }
      throw StateError('Unexpected Nxsha request: $uri');
    });
    final provider = NxshaProvider(httpClient: client);

    final tracks = await provider.listSubtitles(_movie);
    expect(tracks, hasLength(1));
    expect(tracks.single.label, 'English');
    expect(tracks.single.language, 'en');
    final subtitle = await provider.fetchSubtitle(tracks.single.ref);
    expect(subtitle.contentType, 'text/vtt; charset=utf-8');
    expect(subtitle.text, 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n');
    await expectLater(provider.fetchSubtitle('https://evil.example/download/src-api/file.srt'), throwsA(isA<ProviderHttpException>()));
  });
}

final class _FakeHttpClient implements ProviderHttpClient {
  _FakeHttpClient(this.respond);

  final ProviderHttpResponse Function(Uri uri, Map<String, String> headers) respond;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async => respond(uri, headers);
}

final class _FakeBrowserFetchClient implements SameOriginBrowserFetchClient {
  _FakeBrowserFetchClient(this.respond);

  final ProviderHttpResponse Function(Uri uri, Map<String, String> headers) respond;

  @override
  Future<ProviderHttpResponse> fetch(Uri uri, {required Map<String, String> headers, required Duration timeout}) async => respond(uri, headers);
}

ProviderHttpResponse _ok(String body, {Map<String, String> headers = const {}}) => ProviderHttpResponse(statusCode: 200, body: body, headers: headers);

ProviderHttpResponse _json(Object value) => _ok(jsonEncode(value));
