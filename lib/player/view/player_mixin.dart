import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/history/tools/storage/history_storage_client.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
import 'package:popcorn_flutter/player/core/use_case/media_available.dart';
import 'package:popcorn_flutter/player/core/use_case/play_media.dart';
import 'package:popcorn_flutter/player/core/use_case/play_next_media.dart';
import 'package:popcorn_flutter/player/core/use_case/play_previous_media.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/vidsrc_media_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/tools/inapp_web/inapp_webview.dart';

mixin PlayerMixin {
  final _videoType = VidsrcType.fromString(ServiceLocator.configuration.vidsrcInstance);
  final _history = const HistoryStorageClient();
  late final _player = VidsrcMediaPlayer(renderer: InAppWebRenderer(), instance: _videoType.instance);
  
  late final PlayCurrentMediaItem _currentItemPlayer = PlayCurrentMediaItem(player: _player, storage: _history);
  late final PlayPreviousMediaItem _previousItemPlayer = PlayPreviousMediaItem(player: _player, storage: _history);
  late final PlayNextMediaItem _nextItemPlayer = PlayNextMediaItem(player: _player, storage: _history);
  late final AvailableMediaItem _avMedia = AvailableMediaItem(player: _player);

  @Deprecated('Use player settings')
  void openPlayer(MediaInfo info) {
    _currentItemPlayer.playMedia(info);
  }

  Future<bool> isAvailable(MediaInfo info) {
    return _avMedia.isAvailable(info);
  }

  Future<MediaPlayerSettings?> getPlayerSettings(MediaInfo info) {
    return _currentItemPlayer.run(info);
  }

  Future<MediaPlayerSettings?> getPreviousInfoSettings(MediaInfo info) {
    return _previousItemPlayer.run(info);
  }

  Future<MediaPlayerSettings?> getNextInfoSettings(MediaInfo info) {
    return _nextItemPlayer.run(info);
  }
}