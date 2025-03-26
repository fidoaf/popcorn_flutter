import 'package:popcorn_flutter/history/core/use_case/get_history_media_list.dart';
import 'package:popcorn_flutter/history/core/use_case/remove_history_media_info.dart';
import 'package:popcorn_flutter/history/tools/storage/history_storage_client.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

class MediaHistoryController {
  final _historyList = const GetHistoryMediaList(storage: HistoryStorageClient());
  final _removeHistory = const RemoveHistoryMediaInfo(storage: HistoryStorageClient());

  List<MediaInfo> getHistoryList() {
    return _historyList.get();
  }

  bool isWatching(MediaInfo info) {
    final historys = _historyList.get();
    return historys.any((f) => f.id == info.id);
  }

  Future<bool> removeFromHistory(MediaInfo info) {
    return _removeHistory.remove(info: info);
  }
}
