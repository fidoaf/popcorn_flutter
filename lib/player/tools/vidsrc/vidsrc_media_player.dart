import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/shared/tools/chromium/chromium_handler.dart';

class VidsrcMediaPlayer implements IMediaPlayer {
  static final ChromiumHandler _handler = ChromiumHandler();

  final VidSrcInstance _instance;
  const VidsrcMediaPlayer(this._instance);

  String _getMediaUrl(MediaPlayerRequest request) {
    switch (request.type) {
      case MediaType.movie:
        return '${_instance.baseUrl}/movie/${request.id}';
      case MediaType.series:
        return '${_instance.baseUrl}/tv/${request.id}';
    }
  }

  Future<bool> _openPlayer(String mediaUrl) {
    return _handler.launch(mediaUrl);
    // return launchUrlString(mediaUrl);
  }

  @override
  Future<bool> isAvailable(MediaPlayerRequest request) async {
    // final url = _getMediaUrl(request);
    // final response = await get(Uri.parse(url));
    // return response.statusCode == HttpStatus.accepted;
    return true;
  }

  @override
  Future<bool> playMedia(MediaPlayerRequest request) {
    final url = _getMediaUrl(request);
    return _openPlayer(url);
  }
}
