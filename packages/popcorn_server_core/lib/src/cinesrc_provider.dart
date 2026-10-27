import 'browser_response_capture.dart';
import 'media_request.dart';
import 'provider_capabilities.dart';
import 'redirect_media_provider.dart';
import 'reference_stores.dart';

final class CinesrcProvider implements StreamExtractingProvider, SourceListingProvider, EmbedPageProvider, ClosableMediaProvider {
  CinesrcProvider({
    required BrowserResponseCaptureClient browser,
    required String host,
    String scheme = 'https',
    String path = '/embed/{type}/{id}',
    Map<String, String> parameters = const {'s': '{season}', 'e': '{episode}'},
    this.timeout = const Duration(seconds: 25),
  }) : _browser = browser,
       _redirectProvider = RedirectMediaProvider(id: 'cinesrc', label: 'CineSrc', host: host, scheme: scheme, path: path, parameters: parameters);

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final BrowserResponseCaptureClient _browser;
  final RedirectMediaProvider _redirectProvider;
  final Duration timeout;

  @override
  String get id => 'cinesrc';

  @override
  String get label => _redirectProvider.label;

  Uri get origin => Uri.parse(_redirectProvider.origin);

  @override
  Uri embedUrl(MediaRequest media) => _redirectProvider.embedUrl(media);

  @override
  Future<SourceListing> listSources(MediaRequest media) async {
    final playlist = await _loadPlaylist(media);
    final variants = parseCinesrcVariants(playlist);
    return SourceListing(
      token: null,
      sources: [for (var index = 0; index < variants.length; index++) ProviderSource(ref: '$index', name: variants[index].label)],
    );
  }

  @override
  Future<ResolvedStream> extract(MediaRequest media, {SourceReference? selectedSource}) async {
    final playlist = await _loadPlaylist(media);
    final variants = parseCinesrcVariants(playlist);
    if (selectedSource == null) return ResolvedStream(uri: playlist.uri, type: 'hls');
    final index = int.tryParse('${selectedSource.source['ref'] ?? ''}');
    if (index == null || index < 0 || index >= variants.length) {
      throw const InvalidMediaRequest('Selected CineSrc quality is no longer available; reload the player');
    }
    return ResolvedStream(uri: variants[index].uri, type: 'hls');
  }

  @override
  Future<void> close() => _browser.close();

  Future<BrowserCapturedResponse> _loadPlaylist(MediaRequest media) async {
    final response = await _browser.captureFirstResponse(
      navigationUri: embedUrl(media),
      matches: (uri, statusCode) =>
          uri.origin == origin.origin &&
          uri.path.startsWith('/api/playlist/') &&
          uri.path.toLowerCase().endsWith('.m3u8') &&
          statusCode >= 200 &&
          statusCode < 400,
      options: BrowserCaptureOptions(timeout: timeout, userAgent: _userAgent, beforeLoadScripts: const [cinesrcNavigationHardeningScript]),
    );
    if (!response.body.trimLeft().startsWith('#EXTM3U')) {
      throw const FormatException('CineSrc returned an invalid HLS playlist');
    }
    return response;
  }
}

final class CinesrcVariant {
  const CinesrcVariant({required this.uri, required this.label});

  final Uri uri;
  final String label;
}

List<CinesrcVariant> parseCinesrcVariants(BrowserCapturedResponse playlist) {
  final lines = playlist.body.split(RegExp(r'\r?\n')).map((line) => line.trim()).toList();
  final variants = <CinesrcVariant>[];
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
    final attributes = _parsePlaylistAttributes(line.substring(line.indexOf(':') + 1));
    var uriLine = index + 1;
    while (uriLine < lines.length && (lines[uriLine].isEmpty || lines[uriLine].startsWith('#'))) {
      uriLine++;
    }
    if (uriLine >= lines.length) continue;
    final uri = playlist.uri.resolve(lines[uriLine]);
    if (!{'http', 'https'}.contains(uri.scheme)) continue;
    final resolution = attributes['RESOLUTION']?.split('x');
    final height = resolution != null && resolution.length > 1 ? resolution[1] : null;
    variants.add(CinesrcVariant(uri: uri, label: attributes['NAME'] ?? (height == null ? 'Source ${variants.length + 1}' : '${height}p')));
    index = uriLine;
  }
  return variants.isEmpty ? [CinesrcVariant(uri: playlist.uri, label: 'Auto')] : variants;
}

Map<String, String> _parsePlaylistAttributes(String value) {
  final attributes = <String, String>{};
  for (final match in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(value)) {
    attributes[match.group(1)!] = match.group(2)!.replaceAll(RegExp(r'^"|"$'), '');
  }
  return attributes;
}
