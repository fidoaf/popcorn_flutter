import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/favorites/infrastructure/shared_preferences_favorites_repository.dart';

/// Builds the [FavoritesRepository] implementation used by the app.
abstract final class FavoritesRepositoryFactory {
  const FavoritesRepositoryFactory._();

  static FavoritesRepository create() => SharedPreferencesFavoritesRepository();
}
