import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';

abstract class WebContentRenderSettings {
  const WebContentRenderSettings();
  String get url;
}

abstract class MediaPlayerSettings extends WebContentRenderSettings{
  final MediaPlayerRequest request;
  final HistoryMediaInfo? history;
  MediaPlayerSettings({required this.request, this.history});
  
}
