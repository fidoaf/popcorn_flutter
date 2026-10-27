import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:popcorn_server_core/popcorn_server_core.dart';
import 'package:popcorn_server_runtime/popcorn_server_runtime.dart';

Future<void> main() async {
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

  final provider = _FixtureProvider(Uri.parse('http://${fixture.address.address}:${fixture.port}/master.m3u8'));
  final server = DartPlayerServer(providers: MediaProviderRegistry([provider]), apiTokens: const {}, host: '127.0.0.1', port: 0);
  try {
    final baseUri = await server.start();
    final playerUri = baseUri.replace(
      path: '/player',
      queryParameters: const {'provider': 'fixture', 'type': 'tv', 'id': '42', 'season': '1', 'episode': '2', 'nextSeason': '1', 'nextEpisode': '3'},
    );
    stdout.writeln(playerUri);
    await ProcessSignal.sigint.watch().first;
  } finally {
    await server.stop();
    await fixture.close(force: true);
  }
}

final class _FixtureProvider implements MediaProvider, StreamExtractingProvider, SubtitleListingProvider, SubtitleFetchingProvider {
  const _FixtureProvider(this.manifestUri);

  final Uri manifestUri;

  @override
  String get id => 'fixture';

  @override
  String get label => 'Local fixture';

  @override
  Future<ResolvedStream> extract(MediaRequest media, {SourceReference? selectedSource}) async => ResolvedStream(uri: manifestUri, type: 'hls');

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async => const [
    SubtitleTrack(ref: 'fixture-subtitle', label: 'Fixture English', language: 'en'),
  ];

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async => const SubtitleContent(text: 'WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nFixture subtitle\n');
}
