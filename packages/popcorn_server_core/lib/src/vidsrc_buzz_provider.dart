import 'dart:convert';

import 'media_request.dart';
import 'provider_capabilities.dart';
import 'provider_http_client.dart';
import 'redirect_media_provider.dart';
import 'reference_stores.dart';

final class VidSrcBuzzProvider
    implements
        StreamExtractingProvider,
        SourceListingProvider,
        SubtitleListingProvider,
        SubtitleFetchingProvider,
        EmbedPageProvider {
  VidSrcBuzzProvider({
    required ProviderHttpClient httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient;

  static const _origin = 'https://vidsrc.buzz';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final ProviderHttpClient _httpClient;
  final Duration timeout;
  final RedirectMediaProvider _embedProvider = RedirectMediaProvider(
    id: 'vidsrcbuzz',
    label: 'VidSrc.buzz',
    host: 'vidsrc.buzz',
    path: '/embed/{type}/{id}/{season}/{episode}',
    parameters: {'lang': '{language}', 'sub': '{subtitles}'},
  );

  @override
  String get id => 'vidsrcbuzz';

  @override
  String get label => 'VidSrc.buzz';

  @override
  Uri embedUrl(MediaRequest media) => _embedProvider.embedUrl(media);

  @override
  Future<ResolvedStream> extract(
    MediaRequest media, {
    SourceReference? selectedSource,
  }) async {
    final config = await _loadConfig(media);
    if (selectedSource != null) {
      final candidate = await _json(
        _apiUri({
          'a': 'play',
          'ref': '${selectedSource.source['ref'] ?? ''}',
          't': '${selectedSource.source['token'] ?? ''}',
        }),
      );
      if (candidate['url'] == null) {
        throw const ProviderHttpException(
          'Selected server did not return a playable stream',
        );
      }
      return _validate(candidate);
    }

    final refs = await _serverRefs(config);
    if (refs.isEmpty) {
      throw const ProviderHttpException('No servers available');
    }

    final race = await _json(
      _apiUri({'a': 'race', 'refs': refs.take(6).join(',')}),
    );
    final candidates = race['cands'];
    if (candidates is List) {
      for (final candidate in candidates.whereType<Map>()) {
        try {
          return await _validate(Map<String, dynamic>.from(candidate));
        } on Object {
          // Race candidates are best-effort; try the remaining servers.
        }
      }
    }

    for (final ref in refs) {
      try {
        final candidate = await _json(
          _apiUri({'a': 'play', 'ref': ref, 't': '${config['t'] ?? ''}'}),
        );
        if (candidate['url'] != null) return await _validate(candidate);
      } on Object {
        // Individual servers may fail; continue to the next one.
      }
    }
    throw const ProviderHttpException('No playable stream found');
  }

  @override
  Future<SourceListing> listSources(MediaRequest media) async {
    final config = await _loadConfig(media);
    final servers = await _servers(config);
    final sources = <ProviderSource>[];
    for (final server in servers) {
      final ref = server['ref'];
      if (ref is! String || ref.isEmpty) continue;
      final name = server['name'];
      final language = server['lang'];
      final flag = server['flag'];
      sources.add(
        ProviderSource(
          ref: ref,
          name: name is String && name.isNotEmpty ? name : 'Streaming server',
          language: language is String ? language : '',
          flag: flag is String ? flag : '',
        ),
      );
    }
    final token = config['t'];
    return SourceListing(
      token: token == null ? null : '$token',
      sources: sources,
    );
  }

  @override
  Future<List<SubtitleTrack>> listSubtitles(MediaRequest media) async {
    final config = await _loadConfig(media);
    final result = await _json(
      _apiUri({
        'a': 'subs',
        'type': '${config['type'] ?? ''}',
        'id': '${config['id'] ?? ''}',
        's': '${config['s'] ?? 0}',
        'e': '${config['e'] ?? 0}',
        't': '${config['t'] ?? ''}',
      }),
    );
    final subtitles = result['subs'];
    if (subtitles is! List) return const [];
    return [
      for (final subtitle in subtitles.whereType<Map>())
        if (subtitle['ref'] is String)
          SubtitleTrack(
            ref: subtitle['ref'] as String,
            label: subtitle['label'] is String
                ? subtitle['label'] as String
                : '',
            language: subtitle['lang'] is String
                ? subtitle['lang'] as String
                : '',
          ),
    ];
  }

  @override
  Future<SubtitleContent> fetchSubtitle(String ref) async {
    final response = await _get(_apiUri({'a': 'sub', 'ref': ref}));
    return SubtitleContent(
      text: response.body,
      contentType: response.header('content-type') ?? 'text/vtt; charset=utf-8',
    );
  }

  Future<Map<String, dynamic>> _loadConfig(MediaRequest media) async {
    final response = await _get(embedUrl(media));
    final match = RegExp(
      r'var Q\s*=\s*(\{.*?\});',
      dotAll: true,
    ).firstMatch(response.body);
    if (match == null) {
      throw const FormatException('Player config Q not found in embed page');
    }
    final decoded = jsonDecode(match.group(1)!);
    if (decoded is! Map) throw const FormatException('Invalid player config Q');
    return Map<String, dynamic>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> _servers(
    Map<String, dynamic> config,
  ) async {
    final ssr = config['ssr'];
    final configuredServers = ssr is Map ? ssr['servers'] : null;
    if (configuredServers is List && configuredServers.isNotEmpty) {
      return configuredServers
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    }
    final result = await _json(
      _apiUri({
        'a': 'sources',
        'type': '${config['type'] ?? ''}',
        'id': '${config['id'] ?? ''}',
        's': '${config['s'] ?? 0}',
        'e': '${config['e'] ?? 0}',
        't': '${config['t'] ?? ''}',
      }),
    );
    final servers = result['servers'];
    if (servers is! List) return const [];
    return servers.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<List<String>> _serverRefs(Map<String, dynamic> config) async => [
    for (final server in await _servers(config))
      if (server['ref'] is String && (server['ref'] as String).isNotEmpty)
        server['ref'] as String,
  ];

  Future<ResolvedStream> _validate(Map<String, dynamic> candidate) async {
    final rawUrl = candidate['url'];
    if (rawUrl is! String || rawUrl.isEmpty) {
      throw const ProviderHttpException('Invalid stream URL');
    }
    final uri = Uri.parse(_origin).resolve(rawUrl);
    final type = candidate['type'] is String
        ? candidate['type'] as String
        : 'hls';
    final response = await _get(uri);
    if (type != 'mp4' && !response.body.contains('#EXTM3U')) {
      throw const ProviderHttpException('Not an HLS playlist');
    }
    return ResolvedStream(uri: uri, type: type);
  }

  Uri _apiUri(Map<String, String> parameters) =>
      Uri.parse('$_origin/pl/api.php').replace(queryParameters: parameters);

  Future<Map<String, dynamic>> _json(Uri uri) async {
    final response = await _get(uri);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const FormatException('Expected a JSON object');
    return Map<String, dynamic>.from(decoded);
  }

  Future<ProviderHttpResponse> _get(Uri uri) async {
    final response = await _httpClient.get(
      uri,
      headers: {'User-Agent': _userAgent, 'Referer': '$_origin/'},
      timeout: timeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final reason = response.reasonPhrase.isEmpty
          ? ''
          : ' ${response.reasonPhrase}';
      throw ProviderHttpException(
        '${response.statusCode}$reason from ${uri.path}',
      );
    }
    return response;
  }
}
