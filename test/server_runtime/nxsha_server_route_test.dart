import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  test('serves the authenticated Nxsha server catalog and forces its provider ID', () async {
    final provider = _NxshaServerProvider();
    final server = DartPlayerServer(providers: MediaProviderRegistry([provider]), apiTokens: {'nxsha-token'});
    final client = HttpClient();
    try {
      await server.start();
      expect((await _get(client, server, '/nxsha/servers?type=tv&id=1399&season=2&episode=3')).statusCode, HttpStatus.unauthorized);
      final response = await _get(client, server, '/nxsha/servers?provider=unknown&type=tv&id=1399&season=2&episode=3', token: 'nxsha-token');
      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), [
        {'id': 'nitro', 'scraper': 'nitro'},
      ]);
      expect(provider.receivedMedia?.providerId, 'nxsha');
      expect(provider.receivedMedia?.season, '2');
      expect(provider.receivedMedia?.episode, '3');
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
  return _HttpResult(response.statusCode, await utf8.decoder.bind(response).join());
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

final class _NxshaServerProvider implements MediaProvider, ServerListingProvider {
  @override
  String get id => 'nxsha';

  @override
  String get label => 'Nxsha';

  MediaRequest? receivedMedia;

  @override
  Future<List<Map<String, Object?>>> listServers(MediaRequest media) async {
    receivedMedia = media;
    return const [
      {'id': 'nitro', 'scraper': 'nitro'},
    ];
  }
}
