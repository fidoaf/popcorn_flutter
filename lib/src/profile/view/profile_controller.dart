import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';

/// Holds the account's profiles and the active one, and mediates switching,
/// creating and editing them through the [ProfileRepository].
class ProfileController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  ProfileController({required ProfileRepository repository}) : _repository = repository {
    _load();
  }

  final ProfileRepository _repository;

  List<Profile> _profiles = const [];
  Profile? _active;

  /// All profiles in the account, oldest first.
  List<Profile> get profiles => List.unmodifiable(_profiles);

  /// The currently selected profile, or `null` when signed out.
  Profile? get activeProfile => _active;

  /// The active profile's id, used to detect switches.
  String? get activeProfileId => _active?.id;

  /// Reloads the profile list and active profile, e.g. after sign-in.
  Future<void> reload() => _load();

  Future<void> _load() async {
    _profiles = await _repository.listProfiles();
    _active = await _repository.activeProfile();
    notifyListeners();
  }

  /// Selects [profileId] as active.
  Future<void> switchTo(String profileId) async {
    if (_active?.id == profileId) return;
    await _repository.setActiveProfile(profileId);
    final match = _profiles.where((profile) => profile.id == profileId);
    if (match.isNotEmpty) _active = match.first;
    notifyListeners();
  }

  /// Creates a new profile and returns it.
  Future<Profile> addProfile(String displayName) async {
    final profile = await _repository.createProfile(displayName: displayName);
    _profiles = [..._profiles, profile];
    notifyListeners();
    return profile;
  }

  /// Renames [profileId].
  Future<void> rename(String profileId, String displayName) async {
    _replace(await _repository.updateProfile(profileId, displayName: displayName));
  }

  /// Uploads and applies a new picture for [profileId].
  Future<void> changeAvatar(String profileId, Uint8List bytes, {required String fileExtension}) async {
    final url = await _repository.uploadAvatar(profileId, bytes, fileExtension: fileExtension);
    _replace(await _repository.updateProfile(profileId, avatarUrl: url));
  }

  void _replace(Profile profile) {
    _profiles = [
      for (final existing in _profiles)
        if (existing.id == profile.id) profile else existing,
    ];
    if (_active?.id == profile.id) _active = profile;
    notifyListeners();
  }
}
