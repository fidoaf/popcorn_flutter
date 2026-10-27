import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

void main() {
  test('rewrites nested HLS playlists and forwards byte ranges', () async {
    var receivedRange = '';
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = Uri.parse('http://127.0.0.1:${upstream.port}');
    upstream.listen((request) async {
      final response = request.response;
      if (request.uri.path == '/master.m3u8') {
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          )
          ..write('#EXTM3U\n/variant.m3u8\n');
      } else if (request.uri.path == '/variant.m3u8') {
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType(
            'application',
            'vnd.apple.mpegurl',
          )
          ..write('#EXTM3U\n#EXTINF:4,\n/chunk.ts\n');
      } else if (request.uri.path == '/chunk.ts') {
        receivedRange = request.headers.value(HttpHeaders.rangeHeader) ?? '';
        response
          ..statusCode = HttpStatus.partialContent
          ..headers.contentType = ContentType('video', 'mp2t')
          ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-3/4')
          ..headers.set(HttpHeaders.acceptRangesHeader, 'bytes')
          ..write('data');
      } else {
        response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });

    final server = DartPlayerServer(
      providers: MediaProviderRegistry([_StreamingProvider(origin)]),
      apiTokens: {'test-token'},
    );
    final client = HttpClient();
    try {
      await server.start();

      final masterRequest = await client.getUrl(
        server.baseUri.resolve('/manifest?id=42'),
      );
      masterRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer test-token',
      );
      final masterResponse = await masterRequest.close();
      expect(masterResponse.statusCode, HttpStatus.ok);
      final master = await utf8.decoder.bind(masterResponse).join();
      expect(master, startsWith('#EXTM3U'));
      final variantPath = master
          .split('\n')
          .firstWhere((line) => line.startsWith('/resource/'));

      final variantRequest = await client.getUrl(
        server.baseUri.resolve(variantPath),
      );
      variantRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer test-token',
      );
      final variantResponse = await variantRequest.close();
      expect(variantResponse.statusCode, HttpStatus.ok);
      final variant = await utf8.decoder.bind(variantResponse).join();
      final segmentPath = variant
          .split('\n')
          .firstWhere((line) => line.startsWith('/resource/'));

      final segmentRequest = await client.getUrl(
        server.baseUri.resolve(segmentPath),
      );
      segmentRequest
        ..headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token')
        ..headers.set(HttpHeaders.rangeHeader, 'bytes=0-3');
      final segment = await segmentRequest.close();
      expect(segment.statusCode, HttpStatus.partialContent);
      expect(await utf8.decoder.bind(segment).join(), 'data');
      expect(
        segment.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 0-3/4',
      );
      expect(receivedRange, 'bytes=0-3');
    } finally {
      client.close(force: true);
      await server.stop();
      await upstream.close(force: true);
    }
  });
}

final class _StreamingProvider
    implements MediaProvider, StreamExtractingProvider, EmbedPageProvider {
  const _StreamingProvider(this.origin);

  final Uri origin;

  @override
  String get id => 'test';

  @override
  String get label => 'Test provider';

  @override
  Uri embedUrl(MediaRequest media) => origin.replace(path: '/embed');

  @override
  Future<ResolvedStream> extract(
    MediaRequest media, {
    SourceReference? selectedSource,
  }) async => ResolvedStream(uri: origin.resolve('/master.m3u8'), type: 'hls');
}
