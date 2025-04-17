import 'package:popcorn_flutter/favorite/core/use_case/add_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/core/use_case/remove_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

mixin FavoriteMixin {
  final _favList = const GetFavoriteMediaList(storage: FavoriteStorageClient());
  final _addFav = const AddFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _removeFav = const RemoveFavoriteMediaInfo(
    storage: FavoriteStorageClient(),
  );

  List<MediaInfo> getFavoriteList() {
    return _favList.get();
  }

  bool isFavorite(MediaInfo info) {
    final favorites = _favList.get();
    return favorites.any((f) => f.id == info.id);
  }

  Future<bool> addFavorite(MediaInfo info) {
    return _addFav.add(info: info);
  }

  Future<bool> removeFavorite(MediaInfo info) {
    return _removeFav.remove(info: info);
  }
}
