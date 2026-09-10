import 'dart:typed_data';

import 'package:popcorn_flutter/src/profile/domain/profile.dart';

/// Manages the profiles of the signed-in user's account and tracks which one is
/// active.
///
/// Consumers that only need profile-scoped data (favorites, watch history)
/// depend on [activeProfile]; the rest of the API supports the profile
/// switcher and editor.
abstract interface class ProfileRepository {
  /// All profiles belonging to the caller's account, oldest first. Empty when
  /// signed out.
  Future<List<Profile>> listProfiles();

  /// The caller's currently selected profile, or `null` when signed out.
  Future<Profile?> activeProfile();

  /// Selects [profileId] as the caller's active profile.
  Future<void> setActiveProfile(String profileId);

  /// Creates a new profile in the caller's account and returns it.
  Future<Profile> createProfile({required String displayName, String? avatarUrl});

  /// Updates [profileId]'s display name and/or avatar and returns the result.
  Future<Profile> updateProfile(String profileId, {String? displayName, String? avatarUrl});

  /// Uploads [bytes] as [profileId]'s picture and returns its public URL.
  Future<String> uploadAvatar(String profileId, Uint8List bytes, {required String fileExtension});
}
