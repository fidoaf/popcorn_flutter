import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:popcorn_flutter/src/profile/infrastructure/supabase_profile_repository.dart';

/// Builds the [ProfileRepository] implementation used by the app.
abstract final class ProfileRepositoryFactory {
  const ProfileRepositoryFactory._();

  static ProfileRepository create() => SupabaseProfileRepository();
}
