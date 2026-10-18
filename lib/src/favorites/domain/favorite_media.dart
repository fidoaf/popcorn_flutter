import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaItem] the user has marked as a favorite, together with the
/// [MediaType] it belongs to.
///
/// The [MediaType] is stored alongside the item because a movie and a TV series
/// can share the same numeric [MediaItem.id]; the pair `(type, id)` uniquely
/// identifies a favorite.
final class FavoriteMedia {
  const FavoriteMedia({required this.item, required this.type});

  final MediaItem item;
  final MediaType type;

  /// Whether this favorite refers to the same catalogue entry as the pair
  /// [type] / [id].
  bool matches(MediaType type, int id) => this.type == type && item.id == id;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': item.id,
    'title': item.title,
    'overview': item.overview,
    'posterUrl': item.posterUrl?.toString(),
    'releaseDate': item.releaseDate?.toIso8601String(),
    'latestEpisodeAirDate': item.latestEpisodeAirDate?.toIso8601String(),
    'latestEpisodeNumber': item.latestEpisodeNumber,
    'latestSeasonAirDate': item.latestSeasonAirDate?.toIso8601String(),
    'numberOfSeasons': item.numberOfSeasons,
    'releasedSeasonCount': item.releasedSeasonCount,
    'voteAverage': item.voteAverage,
  };

  factory FavoriteMedia.fromJson(Map<String, dynamic> json) {
    final posterUrl = json['posterUrl'] as String?;
    final releaseDate = json['releaseDate'] as String?;
    final latestEpisodeAirDate = json['latestEpisodeAirDate'] as String?;
    final latestSeasonAirDate = json['latestSeasonAirDate'] as String?;
    return FavoriteMedia(
      type: MediaType.values.firstWhere((type) => type.name == json['type'], orElse: () => MediaType.movie),
      item: MediaItem(
        id: json['id'] as int,
        title: json['title'] as String,
        overview: json['overview'] as String,
        posterUrl: posterUrl == null ? null : Uri.tryParse(posterUrl),
        releaseDate: releaseDate == null ? null : DateTime.tryParse(releaseDate),
        latestEpisodeAirDate: latestEpisodeAirDate == null ? null : DateTime.tryParse(latestEpisodeAirDate),
        latestEpisodeNumber: (json['latestEpisodeNumber'] as num?)?.toInt(),
        latestSeasonAirDate: latestSeasonAirDate == null ? null : DateTime.tryParse(latestSeasonAirDate),
        numberOfSeasons: (json['numberOfSeasons'] as num?)?.toInt(),
        releasedSeasonCount: (json['releasedSeasonCount'] as num?)?.toInt(),
        voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      ),
    );
  }
}
