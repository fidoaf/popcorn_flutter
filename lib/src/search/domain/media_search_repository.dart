import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Contract for searching movies and TV series from a remote catalogue.
///
/// Consumers depend on this abstraction rather than any concrete data
/// source, keeping the feature open for extension (e.g. a different
/// provider or a local cache) without modification.
abstract interface class MediaSearchRepository {
  /// Returns the entries of [mediaType] matching [query].
  /// An empty [query] yields no results.
  Future<List<MediaItem>> search(String query, MediaType mediaType);
}
