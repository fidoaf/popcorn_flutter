import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/search/domain/movie_search_repository.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_movie_search_repository.dart';

/// Builds the [MovieSearchRepository] implementation used by the app,
/// wiring the concrete TMDB data source with its credentials.
abstract final class MovieSearchRepositoryFactory {
  static const String _accessTokenKey = 'tmdb.accessToken';
  const MovieSearchRepositoryFactory._();

  static MovieSearchRepository create() {
    final accessToken = dotenv.env[_accessTokenKey];
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Missing $_accessTokenKey in environment (.env).');
    }
    return TmdbMovieSearchRepository(accessToken: accessToken);
  }
}
