import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/storage/tools/storage_handler.dart';

abstract class IHistoryStorage extends MediaStorageClient{
  const IHistoryStorage();

  Future<HistoryMediaInfo?> getItemHistory(MediaPlayerRequest request);
}