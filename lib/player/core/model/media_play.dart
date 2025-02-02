import 'package:popcorn_flutter/player/core/model/media_player_request.dart';

abstract class IMediaPlayer {
  Future<bool> playMedia(MediaPlayerRequest request);
}
