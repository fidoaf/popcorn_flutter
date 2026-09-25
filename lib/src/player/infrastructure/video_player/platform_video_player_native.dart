import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/fullscreen_controller_factory.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/inappwebview_video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/media_kit/media_kit_video_player.dart';

/// Native platforms drive playback through the in-app WebView by default, or
/// the native `media_kit` player when [engine] selects it.
VideoPlayer createPlatformVideoPlayer({
  Key? key,
  required MediaSource source,
  ValueChanged<Uri>? onUrlChanged,
  VideoPlayerEngine engine = VideoPlayerEngine.webView,
  List<Uri> alternates = const <Uri>[],
}) {
  final fullscreenController = FullscreenControllerFactory.create();
  return switch (engine) {
    VideoPlayerEngine.mediaKit => MediaKitVideoPlayer(
      key: key,
      source: source,
      fullscreenController: fullscreenController,
      alternates: alternates,
      onUrlChanged: onUrlChanged,
    ),
    VideoPlayerEngine.webView => InappwebviewVideoPlayer(key: key, source: source, fullscreenController: fullscreenController, onUrlChanged: onUrlChanged),
  };
}
