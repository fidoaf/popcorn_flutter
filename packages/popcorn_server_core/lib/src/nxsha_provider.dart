import 'dart:convert';

import 'media_request.dart';
import 'nxsha_cipher.dart';
import 'provider_capabilities.dart';
import 'provider_http_client.dart';
import 'redirect_media_provider.dart';
import 'reference_stores.dart';
import 'same_origin_browser_fetch.dart';

final class NxshaProvider
    implements
        StreamExtractingProvider,
        ServerListingProvider,
        SourceListingProvider,
        SubtitleListingProvider,
        SubtitleFetchingProvider,
        EmbedPageProvider {
  NxshaProvider({
    required ProviderHttpClient httpClient,
    this.browserFetchClient,
    String host = 'web.nxsha.app',
    String scheme = 'https',
    String path = '/embed/{type}/{id}/{season}/{episode}',
    Map<String, String> parameters = const {},
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient,
       _embedProvider = RedirectMediaProvider(
         id: 'nxsha',
         label: 'Nxsha',
         host: host,
         scheme: scheme,
         path: path,
         parameters: parameters,
       );

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final ProviderHttpClient _httpClient;
  final SameOriginBrowserFetchClient? browserFetchClient;
  final RedirectMediaProvider _embedProvider;
  final Duration timeout;
  final Map<String, String> _tmdbIdCache = {};
  final Map<String, String> _imdbIdByTmdbId = {};

  Uri get origin => Uri.parse(_embedProvider.origin);

  @override
  String get id => 'nxsha';

  @override
  String get label => 'Nxsha';

  @override
  Uri embedUrl(MediaRequest media) => _embedProvider.embedUrl(media);

  @override
  Future<List<Map<String, Object?>>> listServers(MediaRequest media) async {
    final lookupMedia = await _resolveMedia(media);
    final body = await _request(serversUrl(lookupMedia), responseType: 'json');
    final decoded = _decodeBody(body);
    final servers = decoded?['servers'];
    if (servers is! List) {
      return const [];
    }
    return [
      for (final value in servers.whereType<Map>())
        Map<String, Object?>.from(value),
    ];
  }

  @override
  Future<SourceListing> listSources(MediaRequest media) async =>
      SourceListing(sources: await _listHlsSources(media));

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async {
    final lookupMedia = await _resolveMedia(media);
    final body = await _request(
      subtitlesUrl(lookupMedia),
      responseType: 'json',
    );
    final decoded = _decodeBody(body);
    final entries = decoded?['subtitles'];
    if (entries is! List) {
      return const [];
    }
    return [
      for (final entry in entries.whereType<Map>())
        if (entry['uri'] is String && (entry['uri'] as String).isNotEmpty)
          SubtitleTrack(
            ref: entry['uri'] as String,
            label:
                entry['title'] is String &&
                    (entry['title'] as String).isNotEmpty
                ? entry['title'] as String
                : entry['language'] is String &&
                      (entry['language'] as String).isNotEmpty
                ? entry['language'] as String
                : 'Subtitle',
            language: entry['language'] is String
                ? entry['language'] as String
                : '',
          ),
    ];
  }

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async {
    final uri = _validateSubtitleUrl(ref);
    final response = await _request(
      uri,
      responseType: 'text',
      accept: 'text/vtt, application/x-subrip, text/plain, */*',
    );
    if (response is! String) {
      throw const ProviderHttpException(
        'OpenSubtitles returned an invalid response',
      );
    }
    return SubtitleContent(
      text: _normalizeSubtitleText(response),
      contentType: 'text/vtt; charset=utf-8',
    );
  }

  @override
  Future<ResolvedStream> extract(
    MediaRequest media, {
    SourceReference? selectedSource,
  }) async {
    if (selectedSource != null) {
      final ref = selectedSource.source['ref'];
      final rawUrl = ref is Map ? ref['url'] : null;
      final uri = rawUrl is String ? Uri.tryParse(rawUrl) : null;
      if (uri != null && _isHttpUri(uri)) {
        return ResolvedStream(uri: uri, type: 'hls');
      }
      throw const InvalidMediaRequest(
        'Selected Nxsha source is invalid; reload the player',
      );
    }
    final sources = await _listHlsSources(media);
    if (sources.isEmpty) {
      throw const ProviderHttpException('No direct HLS sources available');
    }
    final raw = sources.first.ref;
    final url = raw is Map ? raw['url'] : null;
    if (url is! String) {
      throw const ProviderHttpException('No direct HLS sources available');
    }
    return ResolvedStream(uri: Uri.parse(url), type: 'hls');
  }

  Uri serversUrl(MediaRequest media) =>
      _apiUrl('/api/servers', _payload(media));

  Uri sourcesUrl(MediaRequest media, String scraper) => _apiUrl(
    '/api/sources',
    {..._payload(media), 'ex_lang': media.lang.isNotEmpty, 'provider': scraper},
  );

  Uri subtitlesUrl(MediaRequest media) =>
      _apiUrl('/api/subtitles', _payload(media));

  Map<String, Object?> _payload(MediaRequest media) => {
    ...buildNxshaServersPayload(media),
    'imdb_id':
        _imdbIdByTmdbId[media.id] ??
        (RegExp(r'^tt\d+$').hasMatch(media.id) ? media.id : ''),
  };

  Future<List<ProviderSource>> _listHlsSources(MediaRequest media) async {
    final lookupMedia = await _resolveMedia(media);
    final servers = await listServers(lookupMedia);
    final eligible = servers.where(
      (server) =>
          server['scraper'] is String &&
          server['scraper'] != 'showbox-online' &&
          server['web_support'] != false,
    );
    final result = <ProviderSource>[];
    final seen = <String>{};
    await Future.wait(
      eligible.map((server) async {
        final scraper = server['scraper'] as String;
        try {
          final body = await _request(
            sourcesUrl(lookupMedia, scraper),
            responseType: 'json',
          );
          final decoded = _decodeBody(body);
          final entries = decoded?['sources'];
          if (entries is! List) return;
          for (final entry in entries.whereType<Map>()) {
            final source = _normalizeHlsSource(entry, server);
            if (source == null || !seen.add('${(source.ref as Map)['url']}')) {
              continue;
            }
            result.add(source);
          }
        } on Object {
          return;
        }
      }),
    );
    return result;
  }

  Future<MediaRequest> _resolveMedia(MediaRequest media) async {
    final id = media.id;
    if (!RegExp(r'^tt\d+$').hasMatch(id)) return media;
    final cached = _tmdbIdCache[id];
    if (cached != null) {
      _imdbIdByTmdbId[cached] = id;
      return _withId(media, cached);
    }
    final response = await _request(embedUrl(media), responseType: 'text');
    final html = response is String ? response : '';
    final match = RegExp(r'\\?"tmdbId\\?"\s*:\s*(\d+)').firstMatch(html);
    if (match == null) {
      throw ProviderHttpException(
        'Nxsha could not resolve IMDb ID $id to a TMDB ID',
      );
    }
    final tmdbId = match.group(1)!;
    _tmdbIdCache[id] = tmdbId;
    _imdbIdByTmdbId[tmdbId] = id;
    return _withId(media, tmdbId);
  }

  Future<Object?> _request(
    Uri uri, {
    required String responseType,
    String? accept,
  }) async {
    final headers = <String, String>{
      'Accept':
          accept ?? (responseType == 'json' ? 'application/json' : 'text/html'),
      'User-Agent': _userAgent,
      'Referer': '${origin.origin}/',
    };
    Object? nodeError;
    try {
      final response = await _httpClient.get(
        uri,
        headers: headers,
        timeout: timeout,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _rejectSubtitleHtml(uri, response.header('content-type'));
        return _parseResponse(response.body, responseType);
      }
      nodeError = ProviderHttpException(
        '${response.statusCode} ${response.reasonPhrase} from ${uri.path}',
      );
    } on Object catch (error) {
      nodeError = error;
    }
    final browser = browserFetchClient;
    if (browser == null) throw nodeError;
    try {
      final response = await browser.fetch(
        uri,
        headers: headers,
        timeout: timeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProviderHttpException(
          '${response.statusCode} ${response.reasonPhrase} from ${uri.path}',
        );
      }
      _rejectSubtitleHtml(uri, response.header('content-type'));
      return _parseResponse(response.body, responseType);
    } on Object catch (browserError) {
      throw ProviderHttpException(
        'Nxsha API request failed: $browserError (direct request: $nodeError)',
      );
    }
  }

  void _rejectSubtitleHtml(Uri uri, String? contentType) {
    if (uri.host == 'dl.opensubtitles.org' &&
        (contentType ?? '').toLowerCase().contains('text/html')) {
      throw const ProviderHttpException(
        'OpenSubtitles returned an HTML error page instead of a subtitle',
      );
    }
  }

  Object? _parseResponse(String body, String responseType) {
    if (responseType == 'text') return body;
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Nxsha returned invalid JSON');
    }
    return Map<String, Object?>.from(decoded);
  }

  Map<String, Object?>? _decodeBody(Object? body) {
    if (body is! Map || body['_hash'] is! String) return null;
    return decodeNxshaData(body['_hash'] as String);
  }

  Uri _apiUrl(String path, Map<String, Object?> payload) => origin
      .replace(path: path)
      .replace(queryParameters: {'q': encodeNxshaData(payload)});

  Uri _validateSubtitleUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'dl.opensubtitles.org' ||
        !uri.path.contains('/download/src-api/')) {
      throw const ProviderHttpException(
        'Nxsha subtitle URL is not an approved OpenSubtitles download',
      );
    }
    return uri;
  }
}

Map<String, Object?> buildNxshaServersPayload(MediaRequest media) {
  final id = media.id;
  final isTmdbId = RegExp(r'^\d+$').hasMatch(id);
  return {
    'tmdbId': isTmdbId ? int.parse(id) : '',
    'imdb_id': RegExp(r'^tt\d+$').hasMatch(id) ? id : '',
    'type': media.type,
    'season': media.type == 'tv' ? int.tryParse(media.season) ?? 0 : 1,
    'episode': media.type == 'tv' ? int.tryParse(media.episode) ?? 0 : 1,
  };
}

MediaRequest _withId(MediaRequest media, String id) => MediaRequest(
  providerId: media.providerId,
  type: media.type,
  id: id,
  lang: media.lang,
  sub: media.sub,
  season: media.season,
  episode: media.episode,
);

ProviderSource? _normalizeHlsSource(Map source, Map<String, Object?> server) {
  if (source['isEmbed'] == true || source['url'] is! String) return null;
  final uri = Uri.tryParse(source['url'] as String);
  if (uri == null || !_isHttpUri(uri)) return null;
  final type = '${source['type'] ?? ''}'.toLowerCase();
  if (!uri.path.toLowerCase().endsWith('.m3u8') &&
      !type.contains('hls') &&
      !type.contains('m3u8')) {
    return null;
  }
  final rawLabels = [
    server['name'],
    source['name'] ?? source['title'] ?? source['quality'],
    source['quality'],
  ].whereType<String>().where((value) => value.isNotEmpty).toSet();
  return ProviderSource(
    ref: {'url': uri.toString()},
    name: rawLabels.isEmpty ? 'HLS source' : rawLabels.join(' · '),
    language: source['language'] is String
        ? source['language'] as String
        : source['lang'] is String
        ? source['lang'] as String
        : '',
    flag: source['flag'] is String
        ? source['flag'] as String
        : server['flag'] is String
        ? server['flag'] as String
        : '',
  );
}

bool _isHttpUri(Uri uri) =>
    const {'http', 'https'}.contains(uri.scheme) &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

String _normalizeSubtitleText(String value) {
  final text = value
      .replaceFirst('\uFEFF', '')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .trim();
  if (RegExp(r'^WEBVTT(?:\s|$)', caseSensitive: false).hasMatch(text)) {
    return '$text\n';
  }
  if (!RegExp(
    r'^\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}',
    multiLine: true,
  ).hasMatch(text)) {
    throw const ProviderHttpException(
      'OpenSubtitles response is not valid SRT or WebVTT',
    );
  }
  final cues = text
      .replaceAll(RegExp(r'^\d+\s*$', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})'),
        (match) => '${match.group(1)}.${match.group(2)}',
      )
      .trim();
  return 'WEBVTT\n\n$cues\n';
}
