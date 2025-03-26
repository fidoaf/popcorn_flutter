import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';
import 'package:popcorn_flutter/storage/core/model/media_storage.dart';

class RemoveHistoryMediaInfo implements UseCase {
  final IMediaStorage _storage;
  const RemoveHistoryMediaInfo({required IMediaStorage storage}) : _storage = storage;

  Future<bool> removeInfo({required MediaInfo info}) async {
    try {
      _storage.remove(info);
      return true;
    } catch (ex) {
      return false;
    }
  }

  Future<bool> remove({required MediaInfo info}) async {
    try {
      _storage.remove(info);
      return true;
    } catch (ex) {
      return false;
    }
  }
}
