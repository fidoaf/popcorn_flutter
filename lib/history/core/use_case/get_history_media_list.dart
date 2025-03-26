import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';
import 'package:popcorn_flutter/storage/core/model/media_storage.dart';

class GetHistoryMediaList implements UseCase {
  final IMediaStorage _storage;
  const GetHistoryMediaList({required IMediaStorage storage}) : _storage = storage;

  List<MediaInfo> get() {
    try {
      return _storage.getAll();
    } catch (ex) {
      return [];
    }
  }
}
