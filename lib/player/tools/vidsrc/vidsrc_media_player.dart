import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
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

  Future<bool> _openPlayer(WebContentRenderSettings settings) {
    return _renderer.launch(settings);
    // return launchUrlString(mediaUrl);
  }

  @override
  Future<bool> isAvailable(MediaPlayerRequest request) async {
    final settings = await getPlayerSettings(request);
    return _renderer.check(settings);
  }

  @override
  Future<bool> playMedia(
    MediaPlayerRequest request, [
    HistoryMediaInfo? history,
  ]) async {
    final settings = await getPlayerSettings(request);
    return _openPlayer(settings);
  }

  @override
  Future<MediaPlayerSettings> getPlayerSettings(
    MediaPlayerRequest request, [
    HistoryMediaInfo? history,
  ]) async {
    return _VidsrcMediaPlayerSettings(instance: _instance, request: request, history: history);
  }
}

class _VidsrcMediaPlayerSettings extends MediaPlayerSettings {
  final VidSrcInstance instance;
  _VidsrcMediaPlayerSettings({required super.request, super.history, required this.instance});

  String _getMediaUrl(MediaPlayerRequest request) {
    switch (request.type) {
      case MediaType.movie:
        return '${instance.baseUrl}/movie?${request.id}&ds_lang=en';
      case MediaType.series:
        final current = history as HistorySeriesInfo?;
        final season = current?.season ?? 1;
        final episode = current?.episode ?? 1;
        return '${instance.baseUrl}/tv?imdb=${request.id}&season=$season&episode=$episode&ds_lang=en';
    }
  }

  @override
  String get url => _getMediaUrl(request);
}
