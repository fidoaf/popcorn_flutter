import 'package:popcorn_flutter/player/core/model/media_player_request.dart';

abstract class IMediaPlayer {
  Future<bool> isAvailable(MediaPlayerRequest request);
  Future<bool> playMedia(MediaPlayerRequest request);
}
