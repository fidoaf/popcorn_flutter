import 'package:popcorn_flutter/history/core/model/history_storage.dart';
import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class PlayNextMediaItem implements UseCase {
  final IMediaPlayer _player;
  final IHistoryStorage _storage;
  const PlayNextMediaItem({
    required IMediaPlayer player,
    required IHistoryStorage storage,
  }) : _player = player,
       _storage = storage;

  Future<MediaPlayerSettings?> run(MediaInfo info) async {
    try {
      final request = MediaPlayerRequest.create(info);
      final current = await _storage.getItemHistory(request);
      final target = current?.next;
      return _player.getPlayerSettings(request, target);
    } catch (ex) {}
    return null;
  }
}
