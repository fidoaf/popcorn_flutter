import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/fullscreen_controller_factory.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/inappwebview_video_player.dart';

abstract final class VideoPlayerFactory {
  const VideoPlayerFactory._();

  static VideoPlayer create({Key? key, required MediaSource source}) {
    return InappwebviewVideoPlayer(key: key, source: source, fullscreenController: FullscreenControllerFactory.create());
  }
}
