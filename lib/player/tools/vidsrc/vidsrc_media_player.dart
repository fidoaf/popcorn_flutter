import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:url_launcher/url_launcher_string.dart';

class VidsrcMediaPlayer implements IMediaPlayer {
  static const String _urlPath = 'https://vidsrc.xyz/embed';

  const VidsrcMediaPlayer();

  Future<bool> playMovie(MediaPlayerRequest request) {
    return launchUrlString('$_urlPath/movie/${request.id}');
  }

  Future<bool> playSeries(MediaPlayerRequest request) {
    return launchUrlString('$_urlPath/tv/${request.id}');
  }

  @override
  Future<bool> playMedia(MediaPlayerRequest request) {
    switch (request.type) {
      case MediaType.movie:
        return playMovie(request);
      case MediaType.series:
        return playSeries(request);
    }
  }
}
