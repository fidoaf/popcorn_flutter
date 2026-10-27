import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  const media = MediaRequest(providerId: 'cinesrc', type: 'movie', id: '1492640', lang: 'en', sub: '1', season: '0', episode: '0');

  test('lists qualities and selects from a fresh signed playlist', () async {
    final browser = _FakeBrowser([
      _response('master-old.m3u8', _master('/1080-old.m3u8', '/720-old.m3u8')),
      _response('master-fresh.m3u8', _master('/1080-fresh.m3u8', '/720-fresh.m3u8')),
    ]);
    final provider = CinesrcProvider(browser: browser, host: 'cinesrc.st');

    final listing = await provider.listSources(media);
    expect(listing.token, isNull);
    expect(listing.sources.map((source) => source.name), ['1080p', '720p']);
    expect(listing.sources.map((source) => source.ref), ['0', '1']);

    final source = SourceReference(source: {'ref': '1'}, providerId: provider.id, mediaKey: 'movie:1492640:0:0:en:1');
    final stream = await provider.extract(media, selectedSource: source);
    expect(stream.uri.toString(), 'https://cinesrc.st/720-fresh.m3u8');
    expect(stream.type, 'hls');
    expect(browser.calls, 2);
    expect(browser.lastOptions?.userAgent, contains('Chrome/120'));
    expect(browser.lastOptions?.javascriptEnabled, isTrue);
    expect(browser.lastOptions?.cacheEnabled, isFalse);
    expect(browser.lastOptions?.beforeLoadScripts, [cinesrcNavigationHardeningScript]);
    expect(browser.lastNavigation?.path, '/embed/movie/1492640');
  });

  test('returns auto quality when the playlist has no variants and rejects stale IDs', () async {
    final browser = _FakeBrowser([_response('master.m3u8', '#EXTM3U\n#EXTINF:4,\nsegment.ts\n'), _response('master.m3u8', _master('/720.m3u8'))]);
    final provider = CinesrcProvider(browser: browser, host: 'cinesrc.st');

    final listing = await provider.listSources(media);
    expect(listing.sources.single.name, 'Auto');
    await expectLater(
      provider.extract(
        media,
        selectedSource: SourceReference(source: {'ref': '4'}, providerId: provider.id, mediaKey: 'ignored'),
      ),
      throwsA(isA<InvalidMediaRequest>()),
    );
  });
}

String _master(String first, [String? second]) =>
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,NAME="1080p"\n$first\n'
    '${second == null ? '' : '#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720,NAME="720p"\n$second\n'}';

BrowserCapturedResponse _response(String path, String body) =>
    BrowserCapturedResponse(uri: Uri.parse('https://cinesrc.st/api/playlist/$path'), statusCode: 200, body: body);

final class _FakeBrowser implements BrowserResponseCaptureClient {
  _FakeBrowser(this.responses);

  final List<BrowserCapturedResponse> responses;
  int calls = 0;
  BrowserCaptureOptions? lastOptions;
  Uri? lastNavigation;

  @override
  Future<BrowserCapturedResponse> captureFirstResponse({
    required Uri navigationUri,
    required bool Function(Uri uri, int statusCode) matches,
    required BrowserCaptureOptions options,
  }) async {
    calls++;
    lastNavigation = navigationUri;
    lastOptions = options;
    final response = responses[(calls - 1).clamp(0, responses.length - 1)];
    if (!matches(response.uri, response.statusCode)) throw StateError('Response did not match filter');
    return response;
  }

  @override
  Future<void> close() async {}
}
