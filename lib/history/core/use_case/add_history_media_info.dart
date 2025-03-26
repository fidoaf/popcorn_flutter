import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';
import 'package:popcorn_flutter/storage/core/model/media_storage.dart';

class AddHistoryMediaInfo implements UseCase {
  final IMediaStorage _storage;
  const AddHistoryMediaInfo({required IMediaStorage storage}) : _storage = storage;

  Future<bool> add({required MediaInfo info}) async {
    try {
      _storage.add(info);
      return true;
    } catch (ex) {
      return false;
    }
  }
}
