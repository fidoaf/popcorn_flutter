import 'dart:convert';

import 'media_request.dart';
import 'provider_http_client.dart';

final class JustWatchProviderLinks {
  JustWatchProviderLinks({
    required ProviderHttpClient httpClient,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient,
       _clock = clock ?? DateTime.now;

  static const _origin = 'https://www.justwatch.com';
  static const _searchPaths = {
    'ES': 'buscar',
    'BR': 'buscar',
    'FR': 'rechercher',
    'DE': 'suche',
    'IT': 'cerca',
    'NL': 'zoeken',
    'US': 'search',
    'GB': 'search',
    'CA': 'search',
    'AU': 'search',
  };

  final ProviderHttpClient _httpClient;
  final DateTime Function() _clock;
  final Duration timeout;
  final Map<String, _CachedLinks> _cache = {};

  Future<Map<String, String>> resolve({
    required String? type,
    required String? title,
    required String? year,
    required String? region,
  }) async {
    final normalizedType = (type ?? '').toLowerCase();
    final normalizedTitle = (title ?? '').trim();
    final normalizedRegion = (region ?? '').toUpperCase();
    if ((normalizedType != 'movie' && normalizedType != 'tv') ||
        normalizedTitle.isEmpty ||
        normalizedTitle.length > 200 ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(normalizedRegion)) {
      throw const InvalidMediaRequest(
        'Provide a valid media type, title and two-letter region',
      );
    }
    final normalizedYear = RegExp(r'^\d{4}$').hasMatch(year ?? '') ? year! : '';
    final key =
        '$normalizedType:$normalizedRegion:${normalizedTitle.toLowerCase()}:$normalizedYear';
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(_clock())) {
      return cached.links;
    }

    final links = await _fetchLinks(
      type: normalizedType,
      title: normalizedTitle,
      year: normalizedYear,
      region: normalizedRegion,
    );
    _cache.remove(key);
    _cache[key] = _CachedLinks(links, _clock().add(const Duration(minutes: 5)));
    if (_cache.length > 128) {
      _cache.remove(_cache.keys.first);
    }
    return links;
  }

  Future<Map<String, String>> _fetchLinks({
    required String type,
    required String title,
    required String year,
    required String region,
  }) async {
    final regionPath = region == 'GB' ? 'uk' : region.toLowerCase();
    final searchPath = _searchPaths[region] ?? 'search';
    final searchUrl = Uri.parse(
      '$_origin/$regionPath/$searchPath',
    ).replace(queryParameters: {'q': year.isEmpty ? title : '$title $year'});
    final searchHtml = await _fetchHtml(searchUrl);
    final titleUrl = _findTitleUrl(
      searchHtml,
      type: type,
      regionPath: regionPath,
      title: title,
      year: year,
    );
    if (titleUrl == null) {
      return const {};
    }
    return _extractOfferLinks(await _fetchHtml(titleUrl));
  }

  Future<String> _fetchHtml(Uri uri) async {
    final response = await _httpClient.get(
      uri,
      headers: const {
        'Accept': 'text/html',
        'User-Agent': 'Mozilla/5.0 Popcorn/1.0',
      },
      timeout: timeout,
    );
    if (response.statusCode != 200) {
      throw ProviderHttpException(
        'JustWatch returned HTTP ${response.statusCode}',
      );
    }
    return response.body;
  }

  Uri? _findTitleUrl(
    String html, {
    required String type,
    required String regionPath,
    required String title,
    required String year,
  }) {
    final candidates = <({Uri uri, String text})>[];
    final anchors = RegExp(
      r"""<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>""",
      caseSensitive: false,
    );
    for (final match in anchors.allMatches(html)) {
      final uri = _safeTitleUrl(match.group(1)!, regionPath, type);
      if (uri == null || candidates.any((entry) => entry.uri == uri)) continue;
      final text = _decodeHtml(
        match.group(2)!.replaceAll(RegExp(r'<[^>]*>'), ' '),
      ).replaceAll(RegExp(r'\s+'), ' ').trim();
      candidates.add((uri: uri, text: text));
    }
    if (candidates.isEmpty) return null;
    final expected = _normalizeTitle(title);
    for (final candidate in candidates) {
      final withoutYear = candidate.text.replaceAll(RegExp(r'\(?\d{4}\)?'), '');
      if (_normalizeTitle(withoutYear) == expected) return candidate.uri;
    }
    if (year.isNotEmpty) {
      for (final candidate in candidates) {
        if (candidate.text.contains(year)) return candidate.uri;
      }
    }
    return candidates.first.uri;
  }

  Uri? _safeTitleUrl(String value, String regionPath, String type) {
    final uri = Uri.tryParse(_decodeHtml(value));
    final resolved = uri?.hasAuthority == true
        ? uri
        : Uri.parse(_origin).resolve(value);
    if (resolved == null ||
        resolved.origin != _origin ||
        resolved.pathSegments.length < 2 ||
        resolved.pathSegments[0] != regionPath) {
      return null;
    }
    final segments = resolved.pathSegments;
    final isMovie = segments.contains('pelicula') || segments.contains('movie');
    final isTv =
        segments.contains('serie') ||
        segments.contains('tv-show') ||
        segments.contains('tv-series');
    return (type == 'movie' && isMovie) || (type == 'tv' && isTv)
        ? resolved
        : null;
  }

  Map<String, String> _extractOfferLinks(String html) {
    final links = <String, String>{};
    final anchors = RegExp(
      r"""<a\b[^>]*href=["']([^"']+)["'][^>]*>""",
      caseSensitive: false,
    );
    for (final match in anchors.allMatches(html)) {
      final uri = Uri.tryParse(_decodeHtml(match.group(1)!));
      if (uri == null ||
          uri.scheme != 'https' ||
          !{'e.justwatch.com', 'click.justwatch.com'}.contains(uri.host) ||
          uri.path != '/a') {
        continue;
      }
      final providerId = _providerIdFromClickout(uri.queryParameters['cx']);
      if (providerId != null) {
        links.putIfAbsent(providerId, () => uri.toString());
      }
    }
    return links;
  }

  String? _providerIdFromClickout(String? encodedContext) {
    if (encodedContext == null || encodedContext.isEmpty) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64.decode(base64.normalize(encodedContext))),
      );
      if (decoded is! Map || decoded['data'] is! List) {
        return null;
      }
      for (final entry in (decoded['data'] as List).whereType<Map>()) {
        final data = entry['data'];
        if (data is Map && data['providerId'] is int) {
          return data['providerId'].toString();
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  String _normalizeTitle(String value) => _stripDiacritics(
    value,
  ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  String _decodeHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'&#39;|&apos;'), "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  String _stripDiacritics(String value) {
    const replacements = {
      'a': '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u0101\u0103\u0105',
      'c': '\u00e7\u0107\u0109\u010d',
      'e': '\u00e8\u00e9\u00ea\u00eb\u0113\u0117\u0119\u011b',
      'i': '\u00ec\u00ed\u00ee\u00ef\u012b\u012f',
      'n': '\u00f1\u0144\u0148',
      'o': '\u00f2\u00f3\u00f4\u00f5\u00f6\u014d\u0151',
      's': '\u015b\u0161',
      'u': '\u00f9\u00fa\u00fb\u00fc\u016b\u016f\u0171',
      'y': '\u00fd\u00ff',
      'z': '\u017a\u017c\u017e',
    };
    var result = value;
    for (final entry in replacements.entries) {
      result = result.replaceAll(
        RegExp('[${entry.value}${entry.value.toUpperCase()}]'),
        entry.key,
      );
    }
    return result;
  }
}

final class _CachedLinks {
  const _CachedLinks(this.links, this.expiresAt);

  final Map<String, String> links;
  final DateTime expiresAt;
}
