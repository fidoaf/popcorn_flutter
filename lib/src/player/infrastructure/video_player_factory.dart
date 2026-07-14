import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';
import 'package:popcorn_flutter/src/player/infrastructure/inappwebview_video_player.dart';

abstract final class VideoPlayerFactory {
  const VideoPlayerFactory._();

  static VideoPlayer create({Key? key, required Uri source}) {
    return InappwebviewVideoPlayer(key: key, source: source);
  }
}
