import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_racer.dart';

/// Extracts direct stream URLs from VidSrc-family embed pages so a native player
/// can play them without a WebView.
///
/// The embed page (e.g. `https://vidsrc.buzz/embed/movie/{id}`) ships its
/// player config inline as `var Q = {...}`, which carries per-server `ref`
/// tokens and a request token `t`. Those refs are exchanged at
/// `/pl/api.php?a=race` for one or more candidate `.m3u8` URLs, mirroring the
/// reference player's `raceStart`/`probeCands` flow. Tokens are short-lived, so
/// resolution must happen immediately before playback.
abstract final class VidSrcResolver {
  const VidSrcResolver._();

  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Number of servers raced at once, matching the reference player's `RACE_W`.
  static const _raceWidth = 6;

  static final _configPattern = RegExp(r'var Q\s*=\s*(\{.*?\});', dotAll: true);

  /// Whether [url] points at a VidSrc-family embed page this resolver handles.
  static bool handles(Uri url) => url.host.contains('vidsrc') && url.path.contains('/embed/');

  /// Resolves [source] into playable stream candidates, or an empty list when
  /// extraction fails (caller should fall back to the embed URL / WebView).
  static Future<List<StreamCandidate>> resolve(MediaSource source) async {
    final origin = '${source.url.scheme}://${source.url.host}';
    final headers = {'User-Agent': _userAgent, 'Referer': '$origin/', ...source.headers};
    try {
      final page = await http.get(source.url, headers: headers);
      if (page.statusCode != 200) return const [];

      final match = _configPattern.firstMatch(page.body);
      if (match == null) return const [];
      final config = jsonDecode(match.group(1)!) as Map<String, dynamic>;

      final refs = await _collectRefs(config, origin, headers);
      if (refs.isEmpty) return const [];

      final raceUri = Uri.parse('$origin/pl/api.php?a=race&refs=${Uri.encodeComponent(refs.join(','))}');
      final race = await http.get(raceUri, headers: headers);
      if (race.statusCode != 200) return const [];

      final decoded = jsonDecode(race.body);
      final cands = decoded is Map<String, dynamic> ? decoded['cands'] : null;
      if (cands is! List) return const [];

      final candidates = <StreamCandidate>[];
      for (final entry in cands) {
        if (entry is! Map) continue;
        final rawUrl = entry['url']?.toString();
        if (rawUrl == null || rawUrl.isEmpty) continue;
        final url = rawUrl.startsWith('http') ? Uri.parse(rawUrl) : Uri.parse('$origin$rawUrl');
        candidates.add(StreamCandidate(url: url, headers: headers, isHls: (entry['type']?.toString() ?? 'hls') == 'hls'));
      }
      return candidates;
    } catch (error) {
      debugPrint('[VidSrcResolver] extraction failed: $error');
      return const [];
    }
  }

  /// Gathers server `ref` tokens from the inline config, falling back to the
  /// `a=sources` endpoint when the page did not server-render them.
  static Future<List<String>> _collectRefs(Map<String, dynamic> config, String origin, Map<String, String> headers) async {
    final ssr = config['ssr'];
    final servers = (ssr is Map && ssr['servers'] is List) ? ssr['servers'] as List : const [];
    final refs = servers.map((s) => s is Map ? s['ref']?.toString() : null).whereType<String>().take(_raceWidth).toList();
    if (refs.isNotEmpty) return refs;

    final token = config['t']?.toString();
    if (token == null) return const [];
    final query = 'type=${config['type']}&id=${config['id']}&s=${config['s'] ?? 0}&e=${config['e'] ?? 0}&t=${Uri.encodeComponent(token)}';
    final response = await http.get(Uri.parse('$origin/pl/api.php?a=sources&$query'), headers: headers);
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(response.body);
    final list = decoded is Map<String, dynamic> ? decoded['servers'] : null;
    if (list is! List) return const [];
    return list.map((s) => s is Map ? s['ref']?.toString() : null).whereType<String>().take(_raceWidth).toList();
  }
}
