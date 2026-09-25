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

  static Future<List<StreamCandidate>> resolve(MediaSource source) async {
    if (VidSrcResolver.handles(source.url)) {
      final resolved = await VidSrcResolver.resolve(source);
      if (resolved.isNotEmpty) return resolved;
    }
    return [StreamCandidate(url: source.url, headers: source.headers, isHls: source.url.path.toLowerCase().contains('.m3u8'))];
  }
}
