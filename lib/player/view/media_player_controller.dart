import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/favorite/core/use_case/add_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/core/use_case/get_favorite_media_list.dart';
import 'package:popcorn_flutter/favorite/core/use_case/remove_favorite_media_info.dart';
import 'package:popcorn_flutter/favorite/tools/storage/favorite_storage_client.dart';
import 'package:popcorn_flutter/history/tools/storage/history_storage_client.dart';
import 'package:popcorn_flutter/player/core/model/media_player_settings.dart';
import 'package:popcorn_flutter/player/core/use_case/media_available.dart';
import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/use_case/media_full_details.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';
import 'package:popcorn_flutter/shared/tools/inapp_web/inapp_webview.dart';

class MediaPlayerController {
  final _videoType = VidsrcType.fromString(ServiceLocator.configuration.vidsrcInstance);
  late final PlayMediaItem _player = PlayMediaItem(player: VidsrcMediaPlayer(renderer: InAppWebRenderer(), instance: _videoType.instance), storage: const HistoryStorageClient());
  late final AvailableMediaItem _avMedia = AvailableMediaItem(player: VidsrcMediaPlayer(renderer: InAppWebRenderer(), instance: _videoType.instance));
  final _listFav = const GetFavoriteMediaList(storage: FavoriteStorageClient());
  final _addFav = const AddFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _removeFav = const RemoveFavoriteMediaInfo(storage: FavoriteStorageClient());
  final _details = DetailMediaItem(searcher: OMDBSearcher(secretKey: ServiceLocator.configuration.omdbKeySecret));

  MediaPlayerController();

  void openPlayer(MediaInfo info) {
    _player.playMedia(info);
  }

  MediaPlayerSettings? getPlayerSettings(MediaInfo info){
    return const MediaPlayerSettings(
                                url:
                                    'https://vidsrc.xyz/embed/tv?imdb=tt11280740&season=1&episode=1&color=e600e6',
                              );
  }

  MediaPlayerSettings? getPreviousInfoSettings(MediaInfo info){
    return null;
  }

MediaPlayerSettings? getNextInfoSettings(MediaInfo info){
    return const MediaPlayerSettings(
                                url:
                                    'https://vidsrc.xyz/embed/tv?imdb=tt11280740&season=1&episode=2&color=e600e6',
                              );
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
