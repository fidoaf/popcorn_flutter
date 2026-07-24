/// A single episode of a TV season, shown when a season is expanded in the
/// per-season details sheet.
final class MediaEpisode {
  const MediaEpisode({required this.episodeNumber, required this.name, this.overview = '', this.stillUrl, this.airDate, this.runtime, this.voteAverage});

  /// Ordinal of the episode within its season.
  final int episodeNumber;

  /// Display name of the episode.
  final String name;

  /// Synopsis of the episode. Empty when unavailable.
  final String overview;

  /// Still image (thumbnail) for the episode.
  final Uri? stillUrl;

  /// Date the episode first aired.
  final DateTime? airDate;

  /// Running time of the episode.
  final Duration? runtime;

  /// Average user rating for the episode.
  final double? voteAverage;
}
