import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/platform_video_player_native.dart'
    if (dart.library.js_interop) 'package:popcorn_flutter/src/player/infrastructure/video_player/platform_video_player_web.dart'
    as platform;

abstract final class VideoPlayerFactory {
  const VideoPlayerFactory._();

  /// Builds the platform's [VideoPlayer]. [engine] selects the backend (WebView
  /// by default, or the native `media_kit` player); [alternates] are extra
  /// stream URLs the native player races against [source] for the fastest one.
  static VideoPlayer create({
    Key? key,
    required MediaSource source,
    ValueChanged<Uri>? onUrlChanged,
    VideoPlayerEngine engine = VideoPlayerEngine.webView,
    List<Uri> alternates = const <Uri>[],
  }) => platform.createPlatformVideoPlayer(key: key, source: source, onUrlChanged: onUrlChanged, engine: engine, alternates: alternates);
}
