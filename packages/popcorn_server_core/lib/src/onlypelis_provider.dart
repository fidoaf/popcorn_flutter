import 'dart:convert';

import 'media_request.dart';
import 'provider_capabilities.dart';
import 'provider_http_client.dart';
import 'reference_stores.dart';

final class OnlyPelisProvider implements StreamExtractingProvider, SubtitleListingProvider, SubtitleFetchingProvider {
  OnlyPelisProvider({required ProviderHttpClient httpClient, required ProviderHttpPostClient postClient, this.timeout = const Duration(seconds: 10)})
    : _httpClient = httpClient,
      _postClient = postClient;

  static const _origin = 'https://onlypelis.com';
  static const _playerOrigin = 'https://paulinito.com';
  static const _tmdbOrigin = 'https://www.themoviedb.org';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _streamDomain = '9bg.net';

  final ProviderHttpClient _httpClient;
  final ProviderHttpPostClient _postClient;
  final Duration timeout;
  final Map<String, Future<int>> _postIdCache = {};

  @override
  String get id => 'onlypelis';

  @override
  String get label => 'OnlyPelis';

  @override
  Future<ResolvedStream> extract(MediaRequest media, {SourceReference? selectedSource}) async {
    final html = await _loadPlayerHtml(media);
    final url = parseOnlyPelisHlsUrl(html);
    return ResolvedStream(uri: url, type: 'hls');
  }

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async => parseOnlyPelisSubtitleTracks(await _loadPlayerHtml(media));

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async {
    final url = _validateOnlyPelisSubtitleUrl(ref);
    final response = await _get(url, _headers(_playerOrigin));
    final text = response.body;
    if ((response.header('content-type') ?? '').toLowerCase().contains('text/html') || RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(text)) {
      throw const ProviderHttpException('OnlyPelis returned an HTML error page instead of subtitles');
    }
    return SubtitleContent(text: _normalizeOnlyPelisSubtitle(text), contentType: 'text/vtt; charset=utf-8');
  }

  Future<String> _loadPlayerHtml(MediaRequest media) async {
    if (media.type != 'movie' && media.type != 'tv') {
      throw const InvalidMediaRequest('OnlyPelis provider supports movies and TV episodes only');
    }
    if (!RegExp(r'^\d+$').hasMatch(media.id)) {
      throw const InvalidMediaRequest('OnlyPelis requires a numeric TMDB ID');
    }
    final postId = await _resolvePostId(media);
    final playerUrl = await _playerUrl(postId, media.type);
    return (await _get(playerUrl, _headers(_origin))).body;
  }

  Future<int> _resolvePostId(MediaRequest media) async {
    final key = [media.type, media.id, media.season, media.episode].join(':');
    final cached = _postIdCache[key];
    if (cached != null) return cached;
    final lookup = _lookupPostId(media);
    _postIdCache[key] = lookup;
    try {
      return await lookup;
    } on Object {
      _postIdCache.remove(key);
      rethrow;
    }
  }

  Future<int> _lookupPostId(MediaRequest media) async {
    final title = await _tmdbTitle(media);
    final candidatePages = await _searchPages(title, media.type);
    for (final candidateUrl in candidatePages.take(10)) {
      try {
        final candidateHtml = (await _get(candidateUrl, _headers(_origin))).body;
        if (!_sameTitle(title, _parsePageHeading(candidateHtml))) continue;
        if (media.type == 'movie') {
          final postId = _parsePostId(candidateHtml);
          if (postId != null) return postId;
          continue;
        }
        final episodeUrl = _parseEpisodeUrl(candidateHtml, media.season, media.episode);
        if (episodeUrl == null) continue;
        final episodeHtml = (await _get(episodeUrl, _headers(_origin))).body;
        final postId = _parsePostId(episodeHtml);
        if (postId != null) return postId;
      } on Object {
        // Search can return stale or non-matching results.
      }
    }
    throw ProviderHttpException('OnlyPelis has no matching ${media.type} page for TMDB ID ${media.id}');
  }

  Future<String> _tmdbTitle(MediaRequest media) async {
    final uri = Uri.parse('$_tmdbOrigin/${media.type}/${Uri.encodeComponent(media.id)}').replace(queryParameters: const {'language': 'es-ES'});
    final html = (await _get(uri, const {'User-Agent': _userAgent, 'Accept': 'text/html'})).body;
    final title = _parseMetaContent(html, 'og:title');
    if (title.isEmpty) {
      throw ProviderHttpException('TMDB returned no localized title for ${media.type} ID ${media.id}');
    }
    return title;
  }

  Future<List<Uri>> _searchPages(String title, String type) async {
    final searchUri = Uri.parse('$_origin/').replace(queryParameters: {'s': title});
    final html = (await _get(searchUri, _headers(_origin))).body;
    final prefix = type == 'movie' ? '/pelicula/' : '/serie/';
    final pages = <Uri>{};
    for (final href in _hrefs(html)) {
      final uri = Uri.parse(_origin).resolve(_decodeOnlyPelisHtml(href));
      if (uri.origin == _origin && uri.path.startsWith(prefix)) {
        pages.add(uri.replace(query: '', fragment: ''));
      }
    }
    return pages.toList();
  }

  Future<Uri> _playerUrl(int postId, String type) async {
    final body = Uri(queryParameters: {'action': 'doo_player_ajax', 'post': '$postId', 'nume': '1', 'type': type}).query;
    final response = await _postClient.post(
      Uri.parse('$_origin/wp-admin/admin-ajax.php'),
      headers: {
        ..._headers(_origin),
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: body,
      timeout: timeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderHttpException('OnlyPelis player lookup returned ${response.statusCode}');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ProviderHttpException('OnlyPelis player lookup returned invalid JSON');
    }
    final embedUrl = decoded is Map ? decoded['embed_url'] : null;
    if (embedUrl is! String) throw const ProviderHttpException('OnlyPelis did not return a player URL');
    final url = Uri.parse(_origin).resolve(embedUrl);
    if (url.scheme != 'https' || url.host != 'paulinito.com' || !RegExp(r'^/player/[A-Za-z0-9_-]+/?$').hasMatch(url.path)) {
      throw const ProviderHttpException('OnlyPelis returned an unsupported player URL');
    }
    return url;
  }

  Future<ProviderHttpResponse> _get(Uri uri, Map<String, String> headers) async {
    final response = await _httpClient.get(uri, headers: headers, timeout: timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProviderHttpException('${uri.host} returned ${response.statusCode}');
    }
    return response;
  }

  Map<String, String> _headers(String referer) => {'User-Agent': _userAgent, 'Referer': '$referer/'};
}

Uri parseOnlyPelisHlsUrl(String html) {
  final match = RegExp(
    r'''(?:\bsources\b|"sources"|'sources')\s*:\s*\[\s*\{\s*(?:\bfile\b|"file"|'file')\s*:\s*("(?:\\.|[^"\\])*")''',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) throw const ProviderHttpException('OnlyPelis player page contains no configured video source');
  final String rawUrl;
  try {
    rawUrl = jsonDecode(match.group(1)!) as String;
  } on Object {
    throw const ProviderHttpException('OnlyPelis player page contains an invalid video URL');
  }
  final url = Uri.parse(rawUrl);
  if (!_isOnlyPelisStreamUrl(url) || !url.path.toLowerCase().endsWith('.m3u8')) {
    throw const ProviderHttpException('OnlyPelis player page returned an unsupported HLS URL');
  }
  return url;
}

List<SubtitleTrack> parseOnlyPelisSubtitleTracks(String html) {
  final match = RegExp(r'''(?:\btracks\b|"tracks"|'tracks')\s*:\s*\[([\s\S]*?)\]\s*(?:,|\})''').firstMatch(html);
  if (match == null) return const [];
  final subtitles = <SubtitleTrack>[];
  for (final entry in RegExp(r'\{([^{}]*)\}').allMatches(match.group(1)!)) {
    final fields = entry.group(1)!;
    final kind = _readStringProperty(fields, 'kind')?.toLowerCase();
    if (kind != 'captions' && kind != 'subtitles') continue;
    final rawUrl = _readStringProperty(fields, 'file');
    if (rawUrl == null) continue;
    final Uri url;
    try {
      url = _validateOnlyPelisSubtitleUrl(rawUrl);
    } on Object {
      continue;
    }
    final label = _readStringProperty(fields, 'label') ?? _readStringProperty(fields, 'language') ?? 'Subtitle ${subtitles.length + 1}';
    subtitles.add(
      SubtitleTrack(ref: url.toString(), label: label, language: _readStringProperty(fields, 'language') ?? _readStringProperty(fields, 'lang') ?? ''),
    );
  }
  return subtitles;
}

Uri _validateOnlyPelisSubtitleUrl(String value) {
  final uri = Uri.parse(value);
  if (!_isOnlyPelisStreamUrl(uri) || !RegExp(r'\.(srt|vtt)$', caseSensitive: false).hasMatch(uri.path)) {
    throw const ProviderHttpException('OnlyPelis returned an unsupported subtitle URL');
  }
  return uri;
}

bool _isOnlyPelisStreamUrl(Uri uri) =>
    uri.scheme == 'https' && (uri.host == OnlyPelisProvider._streamDomain || uri.host.endsWith('.${OnlyPelisProvider._streamDomain}')) && uri.userInfo.isEmpty;

String? _readStringProperty(String source, String name) {
  final escaped = RegExp.escape(name);
  final match = RegExp('(?:\\b$escaped\\b|"$escaped"|\'$escaped\')\\s*:\\s*("(?:\\\\.|[^"\\\\])*")').firstMatch(source);
  if (match == null) return null;
  try {
    return jsonDecode(match.group(1)!) as String;
  } on Object {
    return null;
  }
}

Iterable<String> _hrefs(String html) sync* {
  final pattern = RegExp(r'''\bhref\s*=\s*(["'])(.*?)\1''', caseSensitive: false);
  for (final match in pattern.allMatches(html)) {
    yield match.group(2)!;
  }
}

String _parseMetaContent(String html, String property) {
  for (final match in RegExp(r'<meta\b[^>]*>', caseSensitive: false).allMatches(html)) {
    final tag = match.group(0)!;
    final propertyValue = RegExp(r'''\bproperty\s*=\s*(["'])(.*?)\1''', caseSensitive: false).firstMatch(tag)?.group(2);
    if (propertyValue?.toLowerCase() != property.toLowerCase()) continue;
    final content = RegExp(r'''\bcontent\s*=\s*(["'])(.*?)\1''', caseSensitive: false).firstMatch(tag)?.group(2);
    if (content != null) return _decodeOnlyPelisHtml(content).trim();
  }
  return '';
}

String _parsePageHeading(String html) {
  final match = RegExp(r'<h1\b[^>]*>([\s\S]*?)</h1>', caseSensitive: false).firstMatch(html);
  return match == null ? '' : _decodeOnlyPelisHtml(match.group(1)!.replaceAll(RegExp(r'<[^>]*>'), ' ')).trim();
}

int? _parsePostId(String html) {
  for (final match in RegExp(r'<body\b[^>]*>', caseSensitive: false).allMatches(html)) {
    final classValue = RegExp(r'''\bclass\s*=\s*(["'])(.*?)\1''', caseSensitive: false).firstMatch(match.group(0)!)?.group(2);
    final postId = classValue == null ? null : RegExp(r'\bpostid-(\d+)\b', caseSensitive: false).firstMatch(classValue)?.group(1);
    if (postId != null) return int.tryParse(postId);
  }
  return null;
}

Uri? _parseEpisodeUrl(String html, String season, String episode) {
  final seasonNumber = int.tryParse(season) ?? 0;
  final episodeNumber = int.tryParse(episode) ?? 0;
  final suffix = RegExp('-${seasonNumber}x$episodeNumber/?\$', caseSensitive: false);
  for (final href in _hrefs(html)) {
    final uri = Uri.parse(OnlyPelisProvider._origin).resolve(_decodeOnlyPelisHtml(href));
    if (uri.origin == OnlyPelisProvider._origin && uri.path.startsWith('/episodios/') && suffix.hasMatch(uri.path)) {
      return uri.replace(query: '', fragment: '');
    }
  }
  return null;
}

bool _sameTitle(String expected, String actual) => _normalizeOnlyPelisTitle(expected) == _normalizeOnlyPelisTitle(actual);

String _normalizeOnlyPelisTitle(String value) =>
    _stripLatinDiacritics(_decodeOnlyPelisHtml(value)).replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _stripLatinDiacritics(String value) {
  const replacements = {
    'a': '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5',
    'c': '\u00e7',
    'e': '\u00e8\u00e9\u00ea\u00eb',
    'i': '\u00ec\u00ed\u00ee\u00ef',
    'n': '\u00f1',
    'o': '\u00f2\u00f3\u00f4\u00f5\u00f6',
    'u': '\u00f9\u00fa\u00fb\u00fc',
    'y': '\u00fd\u00ff',
  };
  var result = value.toLowerCase();
  for (final entry in replacements.entries) {
    result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return result;
}

String _decodeOnlyPelisHtml(String value) {
  const named = {
    'amp': '&',
    'quot': '"',
    'apos': "'",
    'lt': '<',
    'gt': '>',
    'nbsp': ' ',
    'aacute': '\u00e1',
    'eacute': '\u00e9',
    'iacute': '\u00ed',
    'oacute': '\u00f3',
    'uacute': '\u00fa',
    'ntilde': '\u00f1',
    'uuml': '\u00fc',
  };
  return value.replaceAllMapped(RegExp(r'&(#x[\da-f]+|#\d+|[a-z]+);', caseSensitive: false), (match) {
    final code = match.group(1)!;
    if (code.startsWith('#')) {
      final point = code.substring(1).toLowerCase().startsWith('x') ? int.tryParse(code.substring(2), radix: 16) : int.tryParse(code.substring(1));
      if (point != null && point >= 0 && point <= 0x10ffff) return String.fromCharCode(point);
    } else {
      return named[code.toLowerCase()] ?? match.group(0)!;
    }
    return match.group(0)!;
  });
}

String _normalizeOnlyPelisSubtitle(String input) {
  final text = input.replaceFirst('\uFEFF', '').replaceAll(RegExp(r'\r\n?'), '\n').trim();
  if (RegExp(r'^WEBVTT(?:\s|$)', caseSensitive: false).hasMatch(text)) return '$text\n';
  if (!RegExp(r'^\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}', multiLine: true).hasMatch(text)) {
    throw const ProviderHttpException('OnlyPelis subtitle is not valid SRT or WebVTT');
  }
  final cues = text
      .replaceAll(RegExp(r'^\d+\s*$', multiLine: true), '')
      .replaceAllMapped(RegExp(r'(\d{2}:\d{2}:\d{2}),(\d{3})'), (match) => '${match.group(1)}.${match.group(2)}')
      .trim();
  return 'WEBVTT\n\n$cues\n';
}
