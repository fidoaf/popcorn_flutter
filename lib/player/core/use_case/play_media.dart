import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class PlayMediaItem implements UseCase {
  final IMediaPlayer _player;
  const PlayMediaItem({required IMediaPlayer player}) : _player = player;

  Future<String?> playMedia(MediaInfo info) async {
    try {
      final request = MediaPlayerRequest.create(info);
      await _player.playMedia(request);
    } catch (ex) {
      return ex.toString();
    }
    return null;
  }
}
