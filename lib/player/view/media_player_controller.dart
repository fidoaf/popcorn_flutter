import 'package:popcorn_flutter/app/core/application_configuration.dart';
import 'package:popcorn_flutter/favorite/core/use_case/add_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/core/use_case/remove_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';
import 'package:popcorn_flutter/player/core/use_case/media_available.dart';
import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/use_case/media_full_details.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

class MediaPlayerController {
  final PlayMediaItem _player = const PlayMediaItem(player: VidsrcMediaPlayer());
  final AvailableMediaItem _avMedia = const AvailableMediaItem(player: VidsrcMediaPlayer());
  final _listFav = const GetFavoriteMediaList(storage: FavoriteStorageClient());
  final _addFav = const AddFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _removeFav = const RemoveFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _details = const DetailMediaItem(searcher: OMDBSearcher(secretKey: omdbKeySecret));

  const MediaPlayerController();

  void openPlayer(MediaInfo info) {
    _player.playMedia(info);
  }

  bool isFavorite(MediaInfo info) {
    final favorites = _listFav.get();
    return favorites.any((f) => f.id == info.id);
  }

  Future<bool> addFavorite(MediaInfo info) {
    return _addFav.add(info: info);
  }

  Future<bool> removeFavorite(MediaInfo info) {
    return _removeFav.remove(info: info);
  }

  Future<bool> isAvailable(MediaInfo info) {
    return _avMedia.isAvailable(info);
  }

  Future<MediaInfoResult> getDetails(MediaInfo info) {
    return _details.getDetails(info);
  }
}
