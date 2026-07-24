/// A single season of a TV series, shown in the per-season details sheet.
final class MediaSeason {
  const MediaSeason({required this.seasonNumber, required this.name, this.episodeCount, this.airDate, this.overview = '', this.posterUrl, this.voteAverage});

  /// Ordinal of the season (0 is typically "Specials").
  final int seasonNumber;

  /// Display name of the season (e.g. `Season 1`).
  final String name;

  /// Number of episodes in this season.
  final int? episodeCount;

  /// Date the season first aired.
  final DateTime? airDate;

  /// Synopsis of the season. Empty when unavailable.
  final String overview;

  /// Poster image for the season.
  final Uri? posterUrl;

  /// Average user rating for the season.
  final double? voteAverage;
}
