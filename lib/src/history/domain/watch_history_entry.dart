import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaItem] the user has started watching, together with the [MediaType]
/// it belongs to and, for TV series, the [season]/[episode] left off at.
///
/// As with a favorite, the pair `(type, id)` uniquely identifies an entry: a
/// movie and a TV series can share the same numeric [MediaItem.id]. [watchedAt]
/// records when playback last started so the history can be ordered
/// most-recent-first.
final class WatchHistoryEntry {
  const WatchHistoryEntry({required this.item, required this.type, this.season, this.episode, required this.watchedAt});

  final MediaItem item;
  final MediaType type;

  /// The season currently being watched, for TV series. `null` for movies.
  final int? season;

  /// The episode currently being watched, for TV series. `null` for movies.
  final int? episode;

  /// When playback for this entry last started.
  final DateTime watchedAt;

  /// Whether this entry refers to the same catalogue entry as the pair
  /// [type] / [id].
  bool matches(MediaType type, int id) => this.type == type && item.id == id;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': item.id,
    'title': item.title,
    'overview': item.overview,
    'posterUrl': item.posterUrl?.toString(),
    'releaseDate': item.releaseDate?.toIso8601String(),
    'voteAverage': item.voteAverage,
    'season': season,
    'episode': episode,
    'watchedAt': watchedAt.toIso8601String(),
  };

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    final posterUrl = json['posterUrl'] as String?;
    final releaseDate = json['releaseDate'] as String?;
    final watchedAt = json['watchedAt'] as String?;
    return WatchHistoryEntry(
      type: MediaType.values.firstWhere((type) => type.name == json['type'], orElse: () => MediaType.movie),
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
      watchedAt: watchedAt == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.tryParse(watchedAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      item: MediaItem(
        id: json['id'] as int,
        title: json['title'] as String,
        overview: json['overview'] as String,
        posterUrl: posterUrl == null ? null : Uri.tryParse(posterUrl),
        releaseDate: releaseDate == null ? null : DateTime.tryParse(releaseDate),
        voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      ),
    );
  }
}
