import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';

class PlaybackSessionScope extends InheritedWidget {
  const PlaybackSessionScope({
    super.key,
    required super.child,
    required this.initial,
    required this.onChanged,
    required this.mediaId,
    required this.mediaType,
    this.season,
    this.episode,
  });

  final PlaybackSession initial;
  final ValueChanged<PlaybackSession> onChanged;
  final int mediaId;
  final String mediaType;
  final int? season;
  final int? episode;

  static PlaybackSessionScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PlaybackSessionScope>();

  void accept(dynamic message) {
    if (message is! Map || message['type'] != 'popcorn:playback') return;
    final media = message['media'];
    final session = message['session'];
    if (media is! Map || session is! Map) return;
    if (media['id'].toString() != mediaId.toString() || media['type'] != mediaType) return;
    if (mediaType == 'tv' && (media['season'].toString() != season.toString() || media['episode'].toString() != episode.toString())) return;
    try {
      onChanged(PlaybackSession.fromJson(Map<String, dynamic>.from(session)));
    } on TypeError {
      return;
    }
  }

  @override
  bool updateShouldNotify(PlaybackSessionScope oldWidget) => initial != oldWidget.initial || season != oldWidget.season || episode != oldWidget.episode;
}
