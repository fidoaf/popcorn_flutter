import 'package:popcorn_flutter/favorite/core/model/favorite_media.dart';
import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/core/use_case/remove_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';

class MediaFavoriteController {
  final _favList = const GetFavoriteMediaList(storage: FavoriteStorageClient());
  final _removeFav = const RemoveFavoriteMediaInfo(storage: FavoriteStorageClient());

  Future<List<FavoriteMediaInfo>> getFavoriteList() {
    return _favList.get();
  }

  Future<bool> removeFavorite(FavoriteMediaInfo info) {
    return _removeFav.remove(info: info);
  }
}
