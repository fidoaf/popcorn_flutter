import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/history/tools/storage/history_storage_client.dart';
import 'package:popcorn_flutter/player/core/model/media_player_settings.dart';
import 'package:popcorn_flutter/player/core/use_case/media_available.dart';
import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/tools/inapp_web/inapp_webview.dart';

mixin PlayerMixin {
  final _videoType = VidsrcType.fromString(ServiceLocator.configuration.vidsrcInstance);
  late final PlayMediaItem _player = PlayMediaItem(player: VidsrcMediaPlayer(renderer: InAppWebRenderer(), instance: _videoType.instance), storage: const HistoryStorageClient());
  late final AvailableMediaItem _avMedia = AvailableMediaItem(player: VidsrcMediaPlayer(renderer: InAppWebRenderer(), instance: _videoType.instance));

  void openPlayer(MediaInfo info) {
    _player.playMedia(info);
  }

    Future<bool> isAvailable(MediaInfo info) {
    return _avMedia.isAvailable(info);
  }

  MediaPlayerSettings? getPlayerSettings(MediaInfo info) {
    return const MediaPlayerSettings(
      url:
          'https://vidsrc.xyz/embed/tv?imdb=tt11280740&season=1&episode=1&color=e600e6',
    );
  }

  MediaPlayerSettings? getPreviousInfoSettings(MediaInfo info) {
    return null;
  }

  MediaPlayerSettings? getNextInfoSettings(MediaInfo info) {
    return const MediaPlayerSettings(
      url:
          'https://vidsrc.xyz/embed/tv?imdb=tt11280740&season=1&episode=2&color=e600e6',
    );
  }
}