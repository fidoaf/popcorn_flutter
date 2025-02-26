import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class AddFavoriteMediaInfo implements UseCase {
  final IFavoriteStorage _storage;
  const AddFavoriteMediaInfo({required IFavoriteStorage storage}) : _storage = storage;

  Future<bool> add({required MediaInfo info}) async {
    try {
      _storage.add(info);
      return true;
    } catch (ex) {
      return false;
    }
  }
}
