import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class GetFavoriteMediaList implements UseCase {
  final IFavoriteStorage _storage;
  const GetFavoriteMediaList({required IFavoriteStorage storage}) : _storage = storage;

  List<MediaInfo> get() {
    try {
      return _storage.getAll();
    } catch (ex) {
      return [];
    }
  }
}
