import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class AvailableMediaItem implements UseCase {
  final IMediaPlayer _player;
  const AvailableMediaItem({required IMediaPlayer player}) : _player = player;

  Future<bool> isAvailable(MediaInfo info) async {
    try {
      final request = MediaPlayerRequest.create(info);
      return _player.isAvailable(request);
    } catch (ex) {}
    return false;
  }
}
