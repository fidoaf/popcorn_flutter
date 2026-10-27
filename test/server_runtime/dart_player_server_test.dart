import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  late DartPlayerServer server;
  late HttpClient client;

  setUp(() async {
    final provider = _TestProvider();
    server = DartPlayerServer(
      providers: MediaProviderRegistry([provider]),
      apiTokens: {'test-token'},
    );
    client = HttpClient();
    await server.start();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  test(
    'serves public health and CORS preflight with no-store headers',
    () async {
      final health = await _get(client, server, '/health');
      expect(health.statusCode, HttpStatus.ok);
      expect(health.body, 'ok');
      expect(health.headers.value('access-control-allow-origin'), '*');
      expect(health.headers.value(HttpHeaders.cacheControlHeader), 'no-store');

      final request = await client.openUrl(
        'OPTIONS',
        server.baseUri.resolve('/providers'),
      );
      final preflight = await request.close();
      expect(preflight.statusCode, HttpStatus.noContent);
      expect(
        preflight.headers.value('access-control-allow-headers'),
        'Authorization, Range',
      );
    },
  );

  test('authenticates provider listing and session creation', () async {
    final unauthorized = await _get(client, server, '/providers');
    expect(unauthorized.statusCode, HttpStatus.unauthorized);
    expect(
      unauthorized.headers.value(HttpHeaders.wwwAuthenticateHeader),
      'Bearer',
    );

    final providers = await _get(
      client,
      server,
      '/providers',
      token: 'test-token',
    );
    expect(providers.statusCode, HttpStatus.ok);
    expect(jsonDecode(providers.body), {
      'providers': [
        {'id': 'test', 'label': 'Test provider'},
      ],
      'defaultProvider': 'test',
    });

    final sessionResponse = await _get(
      client,
      server,
      '/session',
      token: 'test-token',
    );
    final session =
        (jsonDecode(sessionResponse.body) as Map)['session'] as String;
    expect(session, matches(RegExp(r'^[a-f0-9]{64}$')));
  });

  test(
    'lists sources and subtitles then resolves their opaque references',
    () async {
      const query = '?id=42';
      final sourcesResponse = await _get(
        client,
        server,
        '/sources$query',
        token: 'test-token',
      );
      final sources = jsonDecode(sourcesResponse.body) as List;
      expect(sources, hasLength(1));
      expect((sources.single as Map)['label'], 'Server A');

      final subtitlesResponse = await _get(
        client,
        server,
        '/subtitles$query',
        token: 'test-token',
      );
      final subtitles = jsonDecode(subtitlesResponse.body) as List;
      expect(subtitles, hasLength(1));
      final subtitleId = (subtitles.single as Map)['id'];
      final subtitle = await _get(
        client,
        server,
        '/subtitle/$subtitleId',
        token: 'test-token',
      );
      expect(subtitle.statusCode, HttpStatus.ok);
      expect(subtitle.body, 'WEBVTT\n');
      expect(subtitle.headers.value(HttpHeaders.contentTypeHeader), 'text/vtt');
    },
  );

  test('rejects unsupported methods and unknown routes', () async {
    final request = await client.postUrl(server.baseUri.resolve('/health'));
    final methodResponse = await request.close();
    expect(methodResponse.statusCode, HttpStatus.methodNotAllowed);

    final unknown = await _get(client, server, '/missing', token: 'test-token');
    expect(unknown.statusCode, HttpStatus.notFound);
  });
}

Future<_HttpResult> _get(
  HttpClient client,
  DartPlayerServer server,
  String path, {
  String? token,
}) async {
  final request = await client.getUrl(server.baseUri.resolve(path));
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  final response = await request.close();
  return _HttpResult(
    response.statusCode,
    response.headers,
    await utf8.decoder.bind(response).join(),
  );
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.headers, this.body);

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

final class _TestProvider
    implements
        MediaProvider,
        SourceListingProvider,
        SubtitleListingProvider,
        SubtitleFetchingProvider {
  @override
  String get id => 'test';

  @override
  String get label => 'Test provider';

  @override
  Future<SourceListing> listSources(MediaRequest media) async => SourceListing(
    token: 'token',
    sources: const [ProviderSource(ref: 'source', name: 'Server A')],
  );

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async => const [
    SubtitleTrack(ref: 'subtitle', label: 'English', language: 'en'),
  ];

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async =>
      const SubtitleContent(text: 'WEBVTT\n', contentType: 'text/vtt');
}
