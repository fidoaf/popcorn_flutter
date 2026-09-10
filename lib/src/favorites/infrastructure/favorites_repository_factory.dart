import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/favorites/infrastructure/supabase_favorites_repository.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';

/// Builds the [FavoritesRepository] implementation used by the app.
abstract final class FavoritesRepositoryFactory {
  const FavoritesRepositoryFactory._();

  static FavoritesRepository create({required ProfileRepository profileRepository}) => SupabaseFavoritesRepository(profileRepository: profileRepository);
}
