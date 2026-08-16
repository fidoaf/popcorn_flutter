import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';

/// Repositories and controllers owned by the app widget so that every named
/// route (including cold-start deep links) can reach the same shared state.
final class AppServices {
  AppServices._({
    required this.repository,
    required this.searchController,
    required this.mediaSourceProvider,
    required this.favoritesController,
    required this.historyController,
    required this.authController,
  });

  factory AppServices.create() {
    final repository = MediaSearchRepositoryFactory.create();
    return AppServices._(
      repository: repository,
      searchController: MediaSearchController(repository: repository),
      mediaSourceProvider: MediaSourceProviderFactory.create(),
      favoritesController: FavoritesController(repository: FavoritesRepositoryFactory.create()),
      historyController: WatchHistoryController(repository: WatchHistoryRepositoryFactory.create()),
      authController: AuthController(),
    );
  }

  final MediaSearchRepository repository;
  final MediaSearchController searchController;
  final ConfigurableMediaSourceProvider mediaSourceProvider;
  final FavoritesController favoritesController;
  final WatchHistoryController historyController;
  final AuthController authController;

  void dispose() {
    searchController.dispose();
    favoritesController.dispose();
    historyController.dispose();
    authController.dispose();
  }
}
