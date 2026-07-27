import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';

/// Contract for persisting the user's favorite media across app launches.
///
/// Consumers depend on this abstraction rather than any concrete storage
/// mechanism, keeping the feature open for extension (e.g. a remote backend)
/// without modification.
abstract interface class FavoritesRepository {
  /// Loads the persisted favorites, or an empty list when none are stored.
  Future<List<FavoriteMedia>> load();

  /// Persists the given [favorites], replacing any previously stored set.
  Future<void> save(List<FavoriteMedia> favorites);
}
