import 'package:popcorn_flutter/favorite/core/model/favorite_media.dart';

abstract class IFavoriteStorage {
  Future<bool> add(FavoriteMediaInfo info);
  Future<bool> remove(FavoriteMediaInfo info);

  Future<List<FavoriteMediaInfo>> getAll();
}
