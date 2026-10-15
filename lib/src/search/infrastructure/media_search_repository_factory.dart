import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/player/infrastructure/player_server_config.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/infrastructure/tmdb_media_search_repository.dart';

/// Builds the [MediaSearchRepository] implementation used by the app,
/// wiring the concrete TMDB data source with its credentials.
abstract final class MediaSearchRepositoryFactory {
  static const String _accessTokenKey = 'tmdb.accessToken';
  static const String _playerServerUrl = String.fromEnvironment('PLAYER_SERVER_URL', defaultValue: 'https://popcorn-flutter.onrender.com');
  const MediaSearchRepositoryFactory._();

  static MediaSearchRepository create() {
    final accessToken = dotenv.env[_accessTokenKey];
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Missing $_accessTokenKey in environment (.env).');
    }
    return TmdbMediaSearchRepository(accessToken: accessToken, playerServerUrl: Uri.parse(_playerServerUrl), playerServerToken: PlayerServerConfig.token);
  }
}
