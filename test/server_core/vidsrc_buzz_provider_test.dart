import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  const media = MediaRequest(
    providerId: 'vidsrcbuzz',
    type: 'movie',
    id: 'tt1375666',
    lang: 'en',
    sub: '1',
    season: '0',
    episode: '0',
  );

  test('extracts and validates an HLS stream through injected HTTP', () async {
    final client = _FakeProviderHttpClient((uri, _) {
      if (uri.path == '/embed/movie/tt1375666') {
        return _ok(
          'var Q = ${jsonEncode({
            'type': 'movie',
            'id': 'tt1375666',
            's': 0,
            'e': 0,
            't': 'token',
            'ssr': {
              'servers': [
                {'ref': 'server-ref'},
              ],
            },
          })};',
        );
      }
      if (uri.path == '/pl/api.php' && uri.queryParameters['a'] == 'race') {
        return _json({
          'cands': [
            {'url': '/stream/master.m3u8', 'type': 'hls'},
          ],
        });
      }
      if (uri.path == '/stream/master.m3u8') {
        return _ok('#EXTM3U\n#EXT-X-ENDLIST');
      }
      throw StateError('Unexpected request: $uri');
    });
    final provider = VidSrcBuzzProvider(httpClient: client);

    final stream = await provider.extract(media);

    expect(stream.uri.toString(), 'https://vidsrc.buzz/stream/master.m3u8');
    expect(stream.type, 'hls');
    expect(client.calls.map((call) => call.uri.path), [
      '/embed/movie/tt1375666',
      '/pl/api.php',
      '/stream/master.m3u8',
    ]);
    expect(client.calls.first.uri.queryParameters, {'lang': 'en', 'sub': '1'});
    expect(client.calls[1].uri.queryParameters['refs'], 'server-ref');
    expect(client.calls.first.headers['Referer'], 'https://vidsrc.buzz/');
  });

  test('lists sources and plays a selected source with its page token', () async {
    final client = _FakeProviderHttpClient((uri, _) {
      if (uri.path == '/embed/movie/tt1375666') {
        return _ok(
          'var Q = ${jsonEncode({
            'type': 'movie',
            'id': 'tt1375666',
            't': 'page-token',
            'ssr': {
              'servers': [
                {'ref': 'first-ref', 'name': 'Server A', 'lang': 'English', 'flag': 'us'},
                {'ref': 'second-ref', 'name': 'Server B'},
              ],
            },
          })};',
        );
      }
      if (uri.path == '/pl/api.php' && uri.queryParameters['a'] == 'play') {
        return _json({'url': '/stream/selected.m3u8', 'type': 'hls'});
      }
      if (uri.path == '/stream/selected.m3u8') return _ok('#EXTM3U');
      throw StateError('Unexpected request: $uri');
    });
    final provider = VidSrcBuzzProvider(httpClient: client);
    final listing = await provider.listSources(media);

    expect(listing.token, 'page-token');
    expect(listing.sources.map((source) => source.name), [
      'Server A',
      'Server B',
    ]);
    expect(listing.sources.last.language, '');
    expect(listing.sources.last.flag, '');

    final reference = SourceReference(
      source: {'ref': 'second-ref', 'token': listing.token},
      providerId: provider.id,
      mediaKey: 'movie:tt1375666:0:0:en:1',
    );
    final stream = await provider.extract(media, selectedSource: reference);
    expect(stream.uri.toString(), 'https://vidsrc.buzz/stream/selected.m3u8');
    final playUri = client.calls
        .firstWhere((call) => call.uri.queryParameters['a'] == 'play')
        .uri;
    expect(playUri.queryParameters['ref'], 'second-ref');
    expect(playUri.queryParameters['t'], 'page-token');
  });

  test('loads subtitle tracks with a fresh token and fetches subtitle text', () async {
    final client = _FakeProviderHttpClient((uri, _) {
      if (uri.path == '/embed/tv/1399/2/3') {
        return _ok(
          'var Q = ${jsonEncode({'type': 'tv', 'id': '1399', 's': 2, 'e': 3, 't': 'fresh-token'})};',
        );
      }
      if (uri.path == '/pl/api.php' && uri.queryParameters['a'] == 'subs') {
        return _json({
          'subs': [
            {'label': 'English', 'lang': 'en', 'ref': 'sub-ref'},
          ],
        });
      }
      if (uri.path == '/pl/api.php' && uri.queryParameters['a'] == 'sub') {
        return ProviderHttpResponse(
          statusCode: 200,
          body: 'WEBVTT\n',
          headers: {'Content-Type': 'text/vtt'},
        );
      }
      throw StateError('Unexpected request: $uri');
    });
    final provider = VidSrcBuzzProvider(httpClient: client);
    const tv = MediaRequest(
      providerId: 'vidsrcbuzz',
      type: 'tv',
      id: '1399',
      lang: 'fr',
      sub: '0',
      season: '2',
      episode: '3',
    );

    final subtitles = await provider.listSubtitles(tv);
    expect(subtitles.single.label, 'English');
    expect(subtitles.single.language, 'en');
    expect(client.calls[0].uri.queryParameters, {'lang': 'fr', 'sub': '0'});
    expect(client.calls[1].uri.queryParameters['t'], 'fresh-token');

    final content = await provider.fetchSubtitle('sub-ref');
    expect(content.text, 'WEBVTT\n');
    expect(content.contentType, 'text/vtt');
  });
}

final class _FakeProviderHttpClient implements ProviderHttpClient {
  _FakeProviderHttpClient(this.respond);

  final ProviderHttpResponse Function(Uri uri, Map<String, String> headers)
  respond;
  final calls = <({Uri uri, Map<String, String> headers, Duration timeout})>[];

  @override
  Future<ProviderHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    calls.add((uri: uri, headers: headers, timeout: timeout));
    return respond(uri, headers);
  }
}

ProviderHttpResponse _ok(String body) =>
    ProviderHttpResponse(statusCode: 200, body: body);

ProviderHttpResponse _json(Object value) => _ok(jsonEncode(value));
