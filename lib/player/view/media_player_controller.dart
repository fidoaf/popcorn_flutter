import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

class MediaPlayerController {
  final PlayMediaItem _player = const PlayMediaItem(player: VidsrcMediaPlayer());
  const MediaPlayerController();

  void openPlayer(MediaInfo info) {
    _player.playMedia(info);
  }
}
