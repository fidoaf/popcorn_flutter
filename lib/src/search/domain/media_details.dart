import 'package:popcorn_flutter/src/search/domain/media_season.dart';

/// Extended information about a movie or TV series, loaded on demand for the
/// details page.
///
/// Movies populate [runtime]; TV series populate [numberOfSeasons],
/// [numberOfEpisodes] and the per-season [seasons] list. Fields that do not
/// apply to a given entry are `null` (or empty for [seasons]).
final class MediaDetails {
  const MediaDetails({
    this.runtime,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.seasons = const <MediaSeason>[],
    this.director,
    this.cast = const <String>[],
  });

  /// Total running time of a movie.
  final Duration? runtime;

  /// Number of seasons of a TV series.
  final int? numberOfSeasons;

  /// Number of episodes of a TV series.
  final int? numberOfEpisodes;

  /// Per-season information for a TV series. Empty for movies.
  final List<MediaSeason> seasons;

  /// Director of a movie or creator(s) of a TV series. `null` when unknown.
  final String? director;

  /// Leading cast members (actor names), most prominent first. Empty when
  /// unknown.
  final List<String> cast;
}
