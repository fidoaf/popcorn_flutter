import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  test('serves the authenticated form and initializes a playback page session', () async {
    final fixture = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fixture.listen((request) async {
      final response = request.response;
      if (request.uri.path == '/master.m3u8') {
        response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        response.write('#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST\n');
      } else if (request.uri.path == '/segment.ts') {
        response.headers.contentType = ContentType.binary;
        response.add(utf8.encode('fixture-segment'));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
    final server = DartPlayerServer(
      providers: MediaProviderRegistry([
        _StreamProvider(Uri.parse('http://${fixture.address.address}:${fixture.port}/master.m3u8')),
        RedirectMediaProvider(id: 'redirect', label: 'Redirect player', host: 'example.test', path: '/embed/{type}/{id}'),
      ]),
      apiTokens: {'page-token'},
    );
    final client = HttpClient();
    try {
      await server.start();
      expect((await _get(client, server, '/favicon.ico')).statusCode, HttpStatus.noContent);
      expect((await _get(client, server, '/')).statusCode, HttpStatus.unauthorized);

      final form = await _get(client, server, '/', token: 'page-token');
      expect(form.statusCode, HttpStatus.ok);
      expect(form.headers.value(HttpHeaders.contentTypeHeader), contains('text/html'));
      expect(form.body, contains('id="media-form"'));
      final session = RegExp(r'const playbackSession = "([a-f0-9]{64})"').firstMatch(form.body)?.group(1);
      expect(session, isNotNull);

      final player = await _get(
        client,
        server,
        '/player?provider=stream&type=tv&id=42&season=1&episode=2&lang=fr&sub=0&session=$session&nextSeason=1&nextEpisode=3',
      );
      expect(player.statusCode, HttpStatus.ok);
      expect(player.body, contains('id="video"'));
      expect(player.body, contains('"providerId":"stream"'));
      expect(player.body, contains('"id":"42"'));
      expect(player.body, contains('id="start-playback"'));
      expect(player.body, contains('id="fullscreen-toggle"'));
      expect(player.body, contains('id="settings-toggle"'));
      expect(player.body, contains('id="playback-settings"'));
      expect(player.body, contains('id="retry"'));
      expect(player.body, contains('id="skip-intro"'));
      expect(player.body, contains('id="next-episode"'));
      expect(player.body, contains("'/introdb?'"));
      expect(player.body, contains('id="quality-select"'));
      expect(player.body, contains('id="subtitle-delay-increase"'));
      expect(player.body, contains("Hls.Events.LEVELS_UPDATED"));

      final query = 'provider=stream&type=tv&id=42&season=1&episode=2&lang=fr&sub=0&session=$session';
      final manifest = await _get(client, server, '/manifest?$query');
      expect(manifest.statusCode, HttpStatus.ok);
      expect(manifest.body, startsWith('#EXTM3U'));
      expect(manifest.body, contains('/resource/'));
      final segmentPath = manifest.body.split('\n').firstWhere((line) => line.startsWith('/resource/'));
      final segment = await _get(client, server, segmentPath);
      expect(segment.statusCode, HttpStatus.ok);
      expect(segment.body, 'fixture-segment');

      final subtitles = await _get(client, server, '/subtitles?$query');
      final subtitleId = (jsonDecode(subtitles.body) as List).single['id'] as String;
      final subtitle = await _get(client, server, '/subtitle/$subtitleId?session=$session');
      expect(subtitle.statusCode, HttpStatus.ok);
      expect(subtitle.body, startsWith('WEBVTT'));

      final embed = await _get(client, server, '/player?provider=redirect&type=movie&id=123', token: 'page-token');
      expect(embed.statusCode, HttpStatus.ok);
      expect(embed.body, contains('https://example.test/embed/movie/123'));
      expect(embed.body, contains('id="embed"'));

      final invalid = await _get(client, server, '/player?provider=stream&type=movie&id=not-an-id', token: 'page-token');
      expect(invalid.statusCode, HttpStatus.badRequest);
    } finally {
      client.close(force: true);
      await server.stop();
      await fixture.close(force: true);
    }
  });
}

Future<_HttpResult> _get(HttpClient client, DartPlayerServer server, String path, {String? token}) async {
  final request = await client.getUrl(server.baseUri.resolve(path));
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  final response = await request.close();
  return _HttpResult(response.statusCode, response.headers, await utf8.decoder.bind(response).join());
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

final class _StreamProvider implements MediaProvider, StreamExtractingProvider, SubtitleListingProvider, SubtitleFetchingProvider {
  const _StreamProvider(this.manifestUri);

  final Uri manifestUri;

  @override
  String get id => 'stream';

  @override
  String get label => 'Stream';

  @override
  Future<ResolvedStream> extract(MediaRequest media, {SourceReference? selectedSource}) async => ResolvedStream(uri: manifestUri, type: 'hls');

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async => const [SubtitleTrack(ref: 'fixture-subtitle', label: 'English', language: 'en')];

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async => const SubtitleContent(text: 'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nFixture subtitle\n');
}
