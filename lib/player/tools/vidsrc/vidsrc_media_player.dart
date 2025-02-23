import 'dart:io';

import 'package:http/http.dart';
import 'package:popcorn_flutter/player/core/model/media_play.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:url_launcher/url_launcher_string.dart';

class VidsrcMediaPlayer implements IMediaPlayer {
  static const String _urlPath = 'https://vidsrc.xyz/embed';

  const VidsrcMediaPlayer();

  String _getMediaUrl(MediaPlayerRequest request) {
    switch (request.type) {
      case MediaType.movie:
        return '$_urlPath/movie/${request.id}';
      case MediaType.series:
        return '$_urlPath/tv/${request.id}';
    }
  }

  Future<bool> _openPlayer(String mediaUrl) {
    return launchUrlString(mediaUrl);
  }

  @override
  Future<bool> isAvailable(MediaPlayerRequest request) async {
    final url = _getMediaUrl(request);
    final response = await get(Uri.parse(url));
    return response.statusCode == HttpStatus.accepted;
  }

  @override
  Future<bool> playMedia(MediaPlayerRequest request) {
    final url = _getMediaUrl(request);
    return _openPlayer(url);
  }
}
