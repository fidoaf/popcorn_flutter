import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class RemoveFavoriteMediaInfo implements UseCase {
  final IFavoriteStorage _storage;
  const RemoveFavoriteMediaInfo({required IFavoriteStorage storage}) : _storage = storage;

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
