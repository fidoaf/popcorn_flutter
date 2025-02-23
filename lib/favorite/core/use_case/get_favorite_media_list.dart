import 'package:popcorn_flutter/favorite/core/model/favorite_media.dart';
import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class GetFavoriteMediaList implements UseCase {
  final IFavoriteStorage _storage;
  const GetFavoriteMediaList({required IFavoriteStorage storage}) : _storage = storage;

  Future<List<FavoriteMediaInfo>> get() async {
    try {
      return _storage.getAll();
    } catch (ex) {
      return [];
    }
  }
}
