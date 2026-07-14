import 'package:popcorn_flutter/src/search/domain/movie.dart';

/// Contract for searching movies from a remote catalogue.
///
/// Consumers depend on this abstraction rather than any concrete data
/// source, keeping the feature open for extension (e.g. a different
/// provider or a local cache) without modification.
abstract interface class MovieSearchRepository {
  /// Returns the movies matching [query]. An empty [query] yields no results.
  Future<List<Movie>> search(String query);
}
