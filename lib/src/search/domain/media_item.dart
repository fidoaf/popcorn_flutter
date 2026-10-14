/// Immutable representation of a movie or TV series returned by a search query.
final class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.overview,
    this.posterUrl,
    this.releaseDate,
    this.latestEpisodeAirDate,
    this.latestEpisodeNumber,
    this.latestSeasonAirDate,
    this.voteAverage,
  });

  final int id;
  final String title;
  final String overview;
  final Uri? posterUrl;
  final DateTime? releaseDate;
  final DateTime? latestEpisodeAirDate;
  final int? latestEpisodeNumber;
  final DateTime? latestSeasonAirDate;
  final double? voteAverage;

  /// Whether the media has been released. Items without a known release date
  /// are treated as unreleased so the play button stays hidden for announced
  /// but unscheduled titles.
  bool get isReleased => releaseDate != null && !releaseDate!.isAfter(DateTime.now());
}
