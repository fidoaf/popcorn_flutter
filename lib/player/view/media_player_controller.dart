import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';
import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

class MediaPlayerController {
  final PlayMediaItem _player = const PlayMediaItem(player: VidsrcMediaPlayer());
  final _listFav = const GetFavoriteMediaList(storage: FavoriteStorageClient());

  const MediaPlayerController();

  void openPlayer(MediaInfo info) {
    _player.playMedia(info);
  }

  bool isFavorite(MediaInfo info) {
    final favorites = _listFav.get();
    return favorites.any((f) => f.id == info.id);
  }
}
