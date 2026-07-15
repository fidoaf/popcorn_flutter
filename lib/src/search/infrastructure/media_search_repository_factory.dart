import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_media_search_repository.dart';

/// Builds the [MediaSearchRepository] implementation used by the app,
/// wiring the concrete TMDB data source with its credentials.
abstract final class MediaSearchRepositoryFactory {
  static const String _accessTokenKey = 'tmdb.accessToken';
  const MediaSearchRepositoryFactory._();

  static MediaSearchRepository create() {
    final accessToken = dotenv.env[_accessTokenKey];
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Missing $_accessTokenKey in environment (.env).');
    }
    return TmdbMediaSearchRepository(accessToken: accessToken);
  }
}
