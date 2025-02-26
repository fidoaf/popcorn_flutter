import 'package:popcorn_flutter/app/core/application_configuration.dart';
import 'package:popcorn_flutter/favorite/core/use_case/add_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/core/use_case/remove_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/core/use_case/search_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

class MediaSearchController {
  final _searcher = const SearchMediaInfo(searcher: OMDBSearcher(secretKey: omdbKeySecret));
  final _listFav = const GetFavoriteMediaList(storage: FavoriteStorageClient());
  final _addFav = const AddFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _removeFav = const RemoveFavoriteMediaInfo(storage: FavoriteStorageClient());

  Future<MediaSearchResult> search({required String terms, int page = 0, MediaType? type}) {
    return _searcher.searchMedia(query: terms, page: page, type: type);
  }

  Future<bool> addFavorite(MediaInfo info) {
    return _addFav.add(info: info);
  }

  Future<bool> removeFavorite(MediaInfo info) {
    return _removeFav.removeInfo(info: info);
  }

  bool isFavorite(MediaInfo info) {
    final favorites = _listFav.get();
    return favorites.any((f) => f.id == info.id);
  }
}
