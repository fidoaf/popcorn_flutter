import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Contract for searching movies and TV series from a remote catalogue.
///
/// Consumers depend on this abstraction rather than any concrete data
/// source, keeping the feature open for extension (e.g. a different
/// provider or a local cache) without modification.
abstract interface class MediaSearchRepository {
  /// Returns the entries of [mediaType] matching [query].
  /// An empty [query] yields no results.
  Future<List<MediaItem>> search(String query, MediaType mediaType);

  /// Returns extended [MediaDetails] for the entry [id] of [mediaType]
  /// (runtime for movies, seasons/episodes for TV series).
  Future<MediaDetails> details(int id, MediaType mediaType);

  /// Returns the single [MediaItem] identified by [id] and [mediaType].
  ///
  /// Used to rebuild a page from a deep link, where only the id and type are
  /// known and the full [MediaItem] must be fetched.
  Future<MediaItem> mediaItem(int id, MediaType mediaType);

  /// Returns the trending entries of [mediaType] for the current week.
  Future<List<MediaItem>> trending(MediaType mediaType);

  /// Returns the videos (trailers, teasers, clips) for the entry [id] of [mediaType].
  Future<List<MediaVideo>> videos(int id, MediaType mediaType);

  /// Returns the episodes of season [seasonNumber] for the TV series [seriesId].
  Future<List<MediaEpisode>> episodes(int seriesId, int seasonNumber);
}
