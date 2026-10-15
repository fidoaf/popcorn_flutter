import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_resolver.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/player_server_session.dart';

void main() {
  final source = MediaSource(
    url: Uri.parse('https://player.example/player?id=42&type=movie&resume=120'),
    headers: const {'Authorization': 'Bearer test-token', 'Accept': 'text/html'},
    sandbox: false,
  );
  final session = List.filled(64, 'a').join();

  test('exchanges bearer header for a playback URL without exposing the bearer', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://player.example/session'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode({'session': session}), 200);
    });
    addTearDown(client.close);
    final result = await createPlayerServerSession(source, client: client);
    expect(result.url.queryParameters, {...source.url.queryParameters, 'session': session});
    expect(result.headers, {'Accept': 'text/html'});
    expect(result.sandbox, isFalse);
    expect(source.headers['Authorization'], 'Bearer test-token');
  });

  test('authorization failure is explicit', () async {
    final client = MockClient((_) async => http.Response('Unauthorized', 401));
    addTearDown(client.close);
    await expectLater(createPlayerServerSession(source, client: client), throwsStateError);
  });

  test('rejects malformed playback credentials', () async {
    final client = MockClient((_) async => http.Response('{"session":"invalid"}', 200));
    addTearDown(client.close);
    await expectLater(createPlayerServerSession(source, client: client), throwsFormatException);
  });

  test('native stream resolution retains sessions for sources, manifests and subtitles', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Uri>[];
    server.listen((request) {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/sources':
          request.response.write('[{"id":"fresh-source","label":"Server 1","language":"English"}]');
        case '/subtitles':
          request.response.write('[{"id":"fresh-subtitle","label":"English","language":"en"}]');
        case '/subtitle/fresh-subtitle':
          request.response.write('WEBVTT\n');
        default:
          request.response.statusCode = 404;
      }
      request.response.close();
    });
    final nativeSource = MediaSource(
      url: Uri.parse('http://127.0.0.1:${server.port}/player').replace(
        queryParameters: {
          'id': '42',
          'type': 'movie',
          'session': session,
          'resumeSource': jsonEncode(['Server 1', 'English']),
        },
      ),
    );
    final candidates = await StreamResolver.resolve(nativeSource);
    expect(candidates.single.url.path, '/manifest');
    expect(candidates.single.url.queryParameters['session'], session);
    expect(candidates.single.url.queryParameters['source'], 'fresh-source');
    final subtitles = await StreamResolver.subtitles(nativeSource);
    expect(subtitles.single.url.path, '/subtitle/fresh-subtitle');
    expect(subtitles.single.url.queryParameters, {'session': session});
    expect(await StreamResolver.subtitleText(nativeSource, subtitles.single), 'WEBVTT\n');
    expect(requests.map((request) => request.queryParameters['session']), everyElement(session));
  });
}
