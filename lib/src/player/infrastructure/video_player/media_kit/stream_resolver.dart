import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/stream_racer.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/vidsrc_resolver.dart';

/// Turns a provider [MediaSource] into direct, playable stream candidates for
/// the native player.
///
/// Some backends hand back an embed *page* rather than a stream URL; those need
/// host-specific extraction (see [VidSrcResolver]) to reach the actual `.m3u8`.
/// Unknown or already-direct sources are returned as a single candidate so the
/// player can open them as-is.
abstract final class StreamResolver {
  const StreamResolver._();

  static bool isHostedPlayer(Uri url) => url.path == '/player' && url.queryParameters.containsKey('id');

  static Map<String, String> _mediaQuery(MediaSource source) => {
    for (final entry in source.url.queryParameters.entries)
      if (['provider', 'id', 'type', 'season', 'episode', 'lang', 'sub'].contains(entry.key)) entry.key: entry.value,
  };

  static Future<List<VidSrcSubtitle>> subtitles(MediaSource source) async {
    if (VidSrcResolver.handles(source.url)) return VidSrcResolver.subtitles(source);
    if (!isHostedPlayer(source.url)) return const [];
    final response = await http
        .get(
          source.url.replace(path: '/subtitles', queryParameters: _mediaQuery(source)),
          headers: source.headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return const [];
    final tracks = jsonDecode(response.body) as List;
    return [
      for (final track in tracks)
        VidSrcSubtitle(
          label: track['label'] as String,
          language: track['language'] as String? ?? '',
          url: source.url.replace(path: '/subtitle/${Uri.encodeComponent(track['id'] as String)}', query: ''),
        ),
    ];
  }

  static Future<String> subtitleText(MediaSource source, VidSrcSubtitle subtitle) async {
    if (!isHostedPlayer(source.url)) return VidSrcResolver.subtitleText(source, subtitle);
    final response = await http.get(subtitle.url, headers: source.headers).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Subtitle download failed (${response.statusCode})');
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static Future<List<StreamCandidate>> resolve(MediaSource source) async {
    if (isHostedPlayer(source.url)) {
      final query = _mediaQuery(source);
      final preferredSource = source.url.queryParameters['resumeSource'];
      var sourceName = '';
      if (preferredSource != null && preferredSource.isNotEmpty) {
        try {
          final response = await http
              .get(
                source.url.replace(path: '/sources', queryParameters: query),
                headers: source.headers,
              )
              .timeout(const Duration(seconds: 20));
          if (response.statusCode == 200) {
            final sources = jsonDecode(response.body) as List;
            final selected = sources.where((entry) => jsonEncode([entry['label'], entry['language'] ?? '']) == preferredSource).firstOrNull;
            if (selected != null) {
              query['source'] = selected['id'] as String;
              sourceName = preferredSource;
            }
          }
        } catch (_) {
          sourceName = '';
        }
      }
      return [
        StreamCandidate(
          url: source.url.replace(path: '/manifest', queryParameters: query),
          headers: source.headers,
          sourceName: sourceName,
        ),
      ];
    }
    if (VidSrcResolver.handles(source.url)) {
      final resolved = await VidSrcResolver.resolve(source);
      if (resolved.isNotEmpty) return resolved;
    }
    return [StreamCandidate(url: source.url, headers: source.headers, isHls: source.url.path.toLowerCase().contains('.m3u8'))];
  }
}
