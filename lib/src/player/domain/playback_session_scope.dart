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
    this.onNextEpisode,
    this.nextSeason,
  });

  final PlaybackSession initial;
  final ValueChanged<PlaybackSession> onChanged;
  final int mediaId;
  final String mediaType;
  final int? season;
  final int? episode;
  final VoidCallback? onNextEpisode;
  final int? nextSeason;

  String get nextEpisodeLabel => season != null && nextSeason != null && nextSeason! > season! ? 'Next season' : 'Next episode';

  static PlaybackSessionScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PlaybackSessionScope>();

  void accept(dynamic message) {
    if (message is! Map || !['popcorn:playback', 'popcorn:next'].contains(message['type'])) return;
    final media = message['media'];
    final session = message['session'];
    if (media is! Map || session is! Map) return;
    if (media['id'].toString() != mediaId.toString() || media['type'] != mediaType) return;
    if (mediaType == 'tv' && (media['season'].toString() != season.toString() || media['episode'].toString() != episode.toString())) return;
    try {
      onChanged(PlaybackSession.fromJson(Map<String, dynamic>.from(session)));
      if (message['type'] == 'popcorn:next') onNextEpisode?.call();
    } on TypeError {
      return;
    }
  }

  @override
  bool updateShouldNotify(PlaybackSessionScope oldWidget) =>
      initial != oldWidget.initial ||
      mediaId != oldWidget.mediaId ||
      mediaType != oldWidget.mediaType ||
      season != oldWidget.season ||
      episode != oldWidget.episode ||
      nextSeason != oldWidget.nextSeason ||
      onNextEpisode != oldWidget.onNextEpisode ||
      onChanged != oldWidget.onChanged;
}
