import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  test('resolves a movie post through TMDB and extracts its HLS source', () async {
    final calls = <_Call>[];
    const streamUrl = 'https://spark.9bg.net/path-token/manifest-token/video.m3u8';
    final client = _FakeOnlyPelisClient((method, uri, body, headers) {
      calls.add(_Call(method, uri, body, headers));
      if (uri.host == 'www.themoviedb.org') {
        return _ok('<meta property="og:title" content="El hombre que desafió al rey">');
      }
      if (uri.host == 'onlypelis.com' && uri.path == '/' && uri.queryParameters.containsKey('s')) {
        return _ok('<a href="/pelicula/el-hombre-que-desafio-al-rey/">Ver detalles</a>');
      }
      if (uri.path == '/pelicula/el-hombre-que-desafio-al-rey/') {
        return _ok('<body class="single postid-13942"><h1>El hombre que desafió al rey (2026)</h1></body>');
      }
      if (uri.path == '/wp-admin/admin-ajax.php') {
        expect(method, 'POST');
        expect(body, 'action=doo_player_ajax&post=13942&nume=1&type=movie');
        return _json({'embed_url': 'https://paulinito.com/player/player-key/'});
      }
      if (uri.path == '/player/player-key/') {
        return _ok('<script>var config = { sources: [{ "file": "$streamUrl", "type": "application/x-mpegURL" }] };</script>');
      }
      throw StateError('Unexpected request: $uri');
    });
    final provider = OnlyPelisProvider(httpClient: client, postClient: client);

    final stream = await provider.extract(_movie);

    expect(stream.uri.toString(), streamUrl);
    expect(stream.type, 'hls');
    expect(calls.first.uri.path, '/movie/977942');
    expect(calls.first.uri.queryParameters['language'], 'es-ES');
    final onlyPelisSearch = calls.firstWhere((call) => call.uri.host == 'onlypelis.com' && call.uri.queryParameters.containsKey('s'));
    expect(onlyPelisSearch.headers['Accept'], isNull);
    expect(onlyPelisSearch.headers['Referer'], 'https://onlypelis.com/');
  });

  test('resolves the selected TV episode post ID', () async {
    final calls = <_Call>[];
    final client = _FakeOnlyPelisClient((method, uri, body, headers) {
      calls.add(_Call(method, uri, body, headers));
      if (uri.host == 'www.themoviedb.org') {
        return _ok('<meta property="og:title" content="Lucky">');
      }
      if (uri.host == 'onlypelis.com' && uri.path == '/' && uri.queryParameters.containsKey('s')) {
        return _ok('<a href="/serie/lucky/">Lucky</a>');
      }
      if (uri.path == '/serie/lucky/') {
        return _ok('<body class="postid-12000"><h1>Lucky (2024)</h1><a href="/episodios/lucky-1x1/">Aang</a></body>');
      }
      if (uri.path == '/episodios/lucky-1x1/') {
        return _ok('<body class="postid-12183"><h1>Lucky: 1x1</h1></body>');
      }
      if (uri.path == '/wp-admin/admin-ajax.php') {
        expect(body, 'action=doo_player_ajax&post=12183&nume=1&type=tv');
        return _json({'embed_url': 'https://paulinito.com/player/episode-key/'});
      }
      if (uri.path == '/player/episode-key/') {
        return _ok('<script>var config = { sources: [{ "file": "https://amber.9bg.net/live.m3u8" }] };</script>');
      }
      throw StateError('Unexpected request: $uri');
    });
    final provider = OnlyPelisProvider(httpClient: client, postClient: client);

    final stream = await provider.extract(_tv);

    expect(stream.uri.toString(), 'https://amber.9bg.net/live.m3u8');
    expect(calls.any((call) => call.uri.path == '/episodios/lucky-1x1/'), isTrue);
  });

  test('lists captions and normalizes SRT subtitles to WebVTT', () async {
    const subtitleUrl = 'https://amber.9bg.net/subtitle-token/subtitles.srt';
    final client = _FakeOnlyPelisClient((method, uri, body, headers) {
      if (uri.host == 'www.themoviedb.org') {
        return _ok('<meta property="og:title" content="Lucky">');
      }
      if (uri.host == 'onlypelis.com' && uri.path == '/' && uri.queryParameters.containsKey('s')) {
        return _ok('<a href="/serie/lucky/">Lucky</a>');
      }
      if (uri.path == '/serie/lucky/') {
        return _ok('<body class="postid-12000"><h1>Lucky</h1><a href="/episodios/lucky-1x1/">Aang</a></body>');
      }
      if (uri.path == '/episodios/lucky-1x1/') {
        return _ok('<body class="postid-12183"></body>');
      }
      if (uri.path == '/wp-admin/admin-ajax.php') {
        return _json({'embed_url': 'https://paulinito.com/player/player-key/'});
      }
      if (uri.path == '/player/player-key/') {
        return _ok(
          '<script>var config = { tracks: [{ "file": "$subtitleUrl", "label": "Español", "kind": "captions", "language": "es" }, { "file": "https://amber.9bg.net/thumbs.vtt", "kind": "thumbnails" }] };</script>',
        );
      }
      if (uri.toString() == subtitleUrl) {
        expect(method, 'GET');
        expect(headers['Referer'], 'https://paulinito.com/');
        return _ok('1\n00:00:01,000 --> 00:00:02,000\nHola\n', headers: {'Content-Type': 'application/x-subrip'});
      }
      throw StateError('Unexpected request: $uri');
    });
    final provider = OnlyPelisProvider(httpClient: client, postClient: client);

    final subtitles = await provider.listSubtitles(_tv);
    expect(subtitles, hasLength(1));
    expect(subtitles.single.ref, subtitleUrl);
    expect(subtitles.single.label, 'Español');
    expect(subtitles.single.language, 'es');
    final content = await provider.fetchSubtitle(subtitles.single.ref);
    expect(content.text, startsWith('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHola'));
    expect(content.contentType, 'text/vtt; charset=utf-8');
  });

  test('rejects invalid media, player URLs and untrusted stream hosts', () async {
    final provider = OnlyPelisProvider(
      httpClient: _FakeOnlyPelisClient((_, uri, _, __) {
        if (uri.host == 'www.themoviedb.org') {
          return _ok('<meta property="og:title" content="Movie title">');
        }
        if (uri.host == 'onlypelis.com' && uri.path == '/') {
          return _ok('<a href="/pelicula/movie-title/">Movie title</a>');
        }
        if (uri.path == '/pelicula/movie-title/') {
          return _ok('<body class="postid-44"><h1>Movie title</h1></body>');
        }
        if (uri.path == '/wp-admin/admin-ajax.php') {
          return _json({'embed_url': 'https://evil.example/player/key/'});
        }
        throw StateError('Unexpected request: $uri');
      }),
      postClient: _FakeOnlyPelisClient((_, uri, _, __) {
        if (uri.path == '/wp-admin/admin-ajax.php') {
          return _json({'embed_url': 'https://evil.example/player/key/'});
        }
        throw StateError('Unexpected POST: $uri');
      }),
    );
    const invalidId = MediaRequest(providerId: 'onlypelis', type: 'movie', id: 'tt12345', lang: 'en', sub: '1', season: '0', episode: '0');
    const invalidType = MediaRequest(providerId: 'onlypelis', type: 'episode', id: '1234', lang: 'en', sub: '1', season: '0', episode: '0');
    await expectLater(provider.extract(invalidId), throwsA(isA<InvalidMediaRequest>()));
    await expectLater(provider.extract(invalidType), throwsA(isA<InvalidMediaRequest>()));
    await expectLater(
      provider.extract(_movie),
      throwsA(isA<ProviderHttpException>().having((error) => error.message, 'message', contains('unsupported player URL'))),
    );
    expect(
      () => parseOnlyPelisHlsUrl('<script>var config = { sources: [{ "file": "https://evil.example/video.m3u8" }] };</script>'),
      throwsA(isA<ProviderHttpException>()),
    );
    expect(parseOnlyPelisSubtitleTracks('<script>tracks: [{ "file": "https://evil.example/sub.srt", "kind": "captions" }]</script>'), isEmpty);
  });
}

const _movie = MediaRequest(providerId: 'onlypelis', type: 'movie', id: '977942', lang: 'en', sub: '1', season: '0', episode: '0');
const _tv = MediaRequest(providerId: 'onlypelis', type: 'tv', id: '1234', lang: 'en', sub: '1', season: '1', episode: '1');

final class _Call {
  const _Call(this.method, this.uri, this.body, this.headers);
  final String method;
  final Uri uri;
  final String? body;
  final Map<String, String> headers;
}

final class _FakeOnlyPelisClient implements ProviderHttpClient, ProviderHttpPostClient {
  _FakeOnlyPelisClient(this.respond);
  final ProviderHttpResponse Function(String method, Uri uri, String? body, Map<String, String> headers) respond;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    return respond('GET', uri, null, headers);
  }

  @override
  Future<ProviderHttpResponse> post(Uri uri, {required Map<String, String> headers, required String body, required Duration timeout}) async {
    return respond('POST', uri, body, headers);
  }
}

ProviderHttpResponse _ok(String body, {Map<String, String> headers = const {}}) => ProviderHttpResponse(statusCode: 200, body: body, headers: headers);

ProviderHttpResponse _json(Object value) => _ok(jsonEncode(value));
