/// Extended information about a movie or TV series, loaded on demand for the
/// details page.
///
/// Movies populate [runtime]; TV series populate [numberOfSeasons] and
/// [numberOfEpisodes]. Fields that do not apply to a given entry are `null`.
final class MediaDetails {
  const MediaDetails({this.runtime, this.numberOfSeasons, this.numberOfEpisodes});

  /// Total running time of a movie.
  final Duration? runtime;

  /// Number of seasons of a TV series.
  final int? numberOfSeasons;

  /// Number of episodes of a TV series.
  final int? numberOfEpisodes;
}
