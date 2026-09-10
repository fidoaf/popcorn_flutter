import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/profile/profile.dart';
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
    required this.profileController,
  });

  static Future<AppServices> create() async {
    final repository = MediaSearchRepositoryFactory.create();
    final profileRepository = ProfileRepositoryFactory.create();
    final services = AppServices._(
      repository: repository,
      searchController: MediaSearchController(repository: repository),
      mediaSourceProvider: await MediaSourceProviderFactory.createFromAsset(),
      favoritesController: FavoritesController(repository: FavoritesRepositoryFactory.create(profileRepository: profileRepository)),
      historyController: WatchHistoryController(repository: WatchHistoryRepositoryFactory.create(profileRepository: profileRepository)),
      authController: AuthController(),
      profileController: ProfileController(repository: profileRepository),
    );
    services._bindReloads();
    return services;
  }

  final MediaSearchRepository repository;
  final MediaSearchController searchController;
  final ConfigurableMediaSourceProvider mediaSourceProvider;
  final FavoritesController favoritesController;
  final WatchHistoryController historyController;
  final AuthController authController;
  final ProfileController profileController;

  bool _wasSignedIn = false;
  String? _lastActiveProfileId;

  // Sign-in changes reload the account's profiles; switching the active profile
  // (which also happens right after sign-in) reloads its favorites and history.
  void _bindReloads() {
    _wasSignedIn = authController.isSignedIn;
    _lastActiveProfileId = profileController.activeProfileId;
    authController.addListener(_handleAuthChange);
    profileController.addListener(_handleProfileChange);
  }

  void _handleAuthChange() {
    final signedIn = authController.isSignedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    profileController.reload();
  }

  void _handleProfileChange() {
    final activeId = profileController.activeProfileId;
    if (activeId == _lastActiveProfileId) return;
    _lastActiveProfileId = activeId;
    favoritesController.reload();
    historyController.reload();
  }

  void dispose() {
    authController.removeListener(_handleAuthChange);
    profileController.removeListener(_handleProfileChange);
    searchController.dispose();
    favoritesController.dispose();
    historyController.dispose();
    authController.dispose();
    profileController.dispose();
  }
}
