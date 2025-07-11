import 'package:flutter/material.dart';
import 'package:popcorn_flutter/details/view/media_details_controller.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
import 'package:popcorn_flutter/player/view/gui/fullscreen_player.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';

class PlayButton extends StatelessWidget {
  final _controller = MediaDetailsController();

  final MediaInfo info;
  final Widget Function({required void Function() action}) builder;
  PlayButton._({required this.info, required this.builder});

  void _showPlayer(MediaPlayerSettings settings) {
    Navigator.push(
      NavigationService.navigatorKey.currentContext!,
      MaterialPageRoute(
        builder:
            (context) => FullScreenMediaPlayer(
              playerSettings: settings,
              onPreviousEpisodeRequested:
                  () => _controller.getPreviousInfoSettings(info),
              onNextEpisodeRequested:
                  () => _controller.getNextInfoSettings(info),
            ),
      ),
    );
  }

  void _playItem() async {
    final settings = await _controller.getPlayerSettings(info);
    if (settings == null) {
    } else {
      _showPlayer(settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return builder(action: _playItem);
  }

  factory PlayButton.floating({required MediaInfo info}) => PlayButton._(
    info: info,
    builder: ({required void Function() action}) {
      return FloatingActionButton.large(
        onPressed: action,
        child: const Icon(Icons.play_circle),
      );
    },
  );

  factory PlayButton.filledTonal({required MediaInfo info}) => PlayButton._(
    info: info,
    builder: ({required void Function() action}) {
      return IconButton.filledTonal(
        onPressed: action,
        icon: const Icon(Icons.play_arrow),
      );
    },
  );
}
