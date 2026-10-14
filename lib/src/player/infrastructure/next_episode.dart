import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

Future<(int, int)?> findNextEpisode(MediaSearchRepository repository, int seriesId, int season, int episode) async {
  final episodes = await repository.episodes(seriesId, season);
  final remaining = episodes.where((value) => value.episodeNumber > episode).toList()
    ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  if (remaining.isNotEmpty) return remaining.first.isReleased ? (season, remaining.first.episodeNumber) : null;
  final details = await repository.details(seriesId, MediaType.tv);
  final seasons = details.seasons.where((value) => value.seasonNumber > season).toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
  for (final next in seasons) {
    final episodes = await repository.episodes(seriesId, next.seasonNumber);
    if (episodes.isEmpty) continue;
    final ordered = episodes.toList()..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return ordered.first.isReleased ? (next.seasonNumber, ordered.first.episodeNumber) : null;
  }
  return null;
}
