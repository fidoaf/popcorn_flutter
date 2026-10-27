import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

const _guideUri = 'https://iptv-epg.org/files/epg-fr.xml';
const _guide = '''<tv>
  <channel id="Example.fr@Paris"><display-name>Example TV</display-name></channel>
  <programme channel="Example.fr@Paris" start="20261015193000 +0200" stop="20261015203000 +0200"><title>Evening news</title></programme>
</tv>''';

void main() {
  test('serves authenticated EPG programmes and returns 404 for unknown channels', () async {
    final outbound = _FakeStreamingHttpClient();
    final catalog = LiveTvCatalog(httpClient: outbound);
    final epg = LiveTvEpg(httpClient: outbound, streamingHttpClient: outbound, clock: () => DateTime.utc(2026, 10, 15, 18));
    final server = DartPlayerServer(
      providers: MediaProviderRegistry([const _Provider()]),
      apiTokens: {'epg-token'},
      providerHttpClient: outbound,
      streamingHttpClient: outbound,
      liveTvCatalog: catalog,
      liveTvEpg: epg,
    );
    final client = HttpClient();
    try {
      await server.start();
      expect((await _get(client, server, '/live-tv/epg?channel=Example.fr')).statusCode, HttpStatus.unauthorized);

      final response = await _get(client, server, '/live-tv/epg?channel=Example.fr', token: 'epg-token');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(jsonDecode(response.body), {
        'programmes': [
          {'title': 'Evening news', 'description': '', 'start': '2026-10-15T17:30:00.000Z', 'end': '2026-10-15T18:30:00.000Z'},
        ],
      });

      final missing = await _get(client, server, '/live-tv/epg?channel=Missing.fr', token: 'epg-token');
      expect(missing.statusCode, HttpStatus.notFound);
      expect(jsonDecode(missing.body), {'error': 'channel_not_found'});
    } finally {
      client.close(force: true);
      await server.stop();
    }
  });

  test('maps guide upstream failures to the live-TV API error response', () async {
    final outbound = _FakeStreamingHttpClient()..failGuide = true;
    final server = DartPlayerServer(
      providers: MediaProviderRegistry([const _Provider()]),
      apiTokens: {'epg-token'},
      providerHttpClient: outbound,
      streamingHttpClient: outbound,
      liveTvCatalog: LiveTvCatalog(httpClient: outbound),
      liveTvEpg: LiveTvEpg(httpClient: outbound, streamingHttpClient: outbound),
    );
    final client = HttpClient();
    try {
      await server.start();
      final response = await _get(client, server, '/live-tv/epg?channel=Example.fr', token: 'epg-token');
      expect(response.statusCode, HttpStatus.badGateway);
      expect(jsonDecode(response.body), {'error': 'live_tv_unavailable'});
    } finally {
      client.close(force: true);
      await server.stop();
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

final class _FakeStreamingHttpClient implements ProviderHttpClient, ProviderStreamingHttpClient {
  bool failGuide = false;

  @override
  Future<ProviderHttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    if (uri.path == '/guides') {
      return ProviderHttpResponse(statusCode: 200, body: '<a href="$_guideUri">France</a>');
    }
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
    return _json(<Object>[]);
  }

  @override
  Future<ProviderHttpStreamResponse> getStream(Uri uri, {required Map<String, String> headers, required Duration timeout}) async => ProviderHttpStreamResponse(
    statusCode: failGuide ? HttpStatus.serviceUnavailable : HttpStatus.ok,
    body: Stream<List<int>>.value(utf8.encode(failGuide ? '' : _guide)),
  );
}

ProviderHttpResponse _json(Object value) => ProviderHttpResponse(statusCode: 200, body: jsonEncode(value));

final class _Provider implements MediaProvider {
  const _Provider();

  @override
  String get id => 'test';

  @override
  String get label => 'Test';
}
