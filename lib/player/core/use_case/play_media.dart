import 'package:popcorn_flutter/history/core/model/history_storage.dart';
import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class PlayMediaItem implements UseCase {
  final IMediaPlayer _player;
  final IHistoryStorage _storage;
  const PlayMediaItem({required IMediaPlayer player, required IHistoryStorage storage}) : _player = player, _storage = storage;

  Future<String?> playMedia(MediaInfo info) async {
    try {
      final request = MediaPlayerRequest.create(info);
      final history = await _storage.getItemHistory(request);
      await _player.playMedia(request, history);
      // Record in watching history
      // await _storage.
    } catch (ex) {
      return ex.toString();
    }
    return null;
  }
}
