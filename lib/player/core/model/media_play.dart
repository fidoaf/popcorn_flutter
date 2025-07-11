import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';

abstract class IMediaPlayer {
  Future<bool> isAvailable(MediaPlayerRequest request);
  @Deprecated('message')
  Future<bool> playMedia(MediaPlayerRequest request, [HistoryMediaInfo? history]);
  Future<MediaPlayerSettings> getPlayerSettings(MediaPlayerRequest request, [HistoryMediaInfo? history]);
}
