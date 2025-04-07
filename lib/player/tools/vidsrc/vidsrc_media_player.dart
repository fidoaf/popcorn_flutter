import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/shared/core/model/web_renderer.dart';

class VidsrcMediaPlayer implements IMediaPlayer {
  final IWebRenderer _renderer;
  final VidSrcInstance _instance;
  const VidsrcMediaPlayer({
    required IWebRenderer renderer,
    required VidSrcInstance instance,
  }) : _renderer = renderer,
       _instance = instance;

  String _getMediaUrl(MediaPlayerRequest request) {
    switch (request.type) {
      case MediaType.movie:
        return '${_instance.baseUrl}/movie/${request.id}';
      case MediaType.series:
        return '${_instance.baseUrl}/tv?imdb=${request.id}&season=1&episode=1&ds_lang=en';
    }
  }

  Future<bool> _openPlayer(String mediaUrl) {
    return _renderer.launch(mediaUrl);
    // return launchUrlString(mediaUrl);
  }

  @override
  Future<bool> isAvailable(MediaPlayerRequest request) async {
    final url = _getMediaUrl(request);
    return _renderer.check(url);
  }

  @override
  Future<bool> playMedia(MediaPlayerRequest request, [HistoryMediaInfo? history]) {
    final url = _getMediaUrl(request);
    return _openPlayer(url);
  }
}
