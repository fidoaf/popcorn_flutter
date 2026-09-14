import 'dart:typed_data';

import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [ProfileRepository] backed by Supabase (`profiles` and the `avatars` storage
/// bucket).
///
/// The account, its default profile, and the membership are provisioned
/// server-side by a trigger on `auth.users`. The active profile selection is
/// kept DEVICE-LOCAL (in [SharedPreferences], keyed by user id) so each device
/// can have its own profile without affecting the others.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  static const String _profiles = 'profiles';
  static const String _members = 'account_members';
  static const String _avatarBucket = 'avatars';
  static const String _activePrefPrefix = 'active_profile_id:';

  final SupabaseClient _client;
  Profile? _activeCache;
  String? _cacheUserId;

  String? get _userId => _client.auth.currentUser?.id;

  Future<String?> _accountId() async {
    final userId = _userId;
    if (userId == null) return null;
    final member = await _client.from(_members).select('account_id').eq('user_id', userId).maybeSingle();
    return member?['account_id'] as String?;
  }

  String _activeKey(String userId) => '$_activePrefPrefix$userId';

  Future<String?> _readLocalActiveId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey(userId));
  }

  Future<void> _writeLocalActiveId(String userId, String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey(userId), profileId);
  }

  @override
  Future<List<Profile>> listProfiles() async {
    if (_userId == null) return const [];
    final rows = await _client.from(_profiles).select().order('created_at');
    return rows.map(Profile.fromRow).toList();
  }

  @override
  Future<Profile?> activeProfile() async {
    final userId = _userId;
    if (userId == null) {
      _activeCache = null;
      _cacheUserId = null;
      return null;
    }
    if (_activeCache != null && _cacheUserId == userId) return _activeCache;

    Profile? profile;
    final activeId = await _readLocalActiveId(userId);
    if (activeId != null) {
      final row = await _client.from(_profiles).select().eq('id', activeId).maybeSingle();
      if (row != null) profile = Profile.fromRow(row);
    }
    // No (or stale) local selection: fall back to the first profile and persist
    // it locally for this device.
    profile ??= await _firstProfileAndActivate();

    _activeCache = profile;
    _cacheUserId = userId;
    return profile;
  }

  Future<Profile?> _firstProfileAndActivate() async {
    final rows = await _client.from(_profiles).select().order('created_at').limit(1);
    if (rows.isEmpty) return null;
    final profile = Profile.fromRow(rows.first);
    await setActiveProfile(profile.id);
    return profile;
  }

  @override
  Future<void> setActiveProfile(String profileId) async {
    final userId = _userId;
    if (userId == null) return;
    await _writeLocalActiveId(userId, profileId);
    final row = await _client.from(_profiles).select().eq('id', profileId).maybeSingle();
    _activeCache = row == null ? null : Profile.fromRow(row);
    _cacheUserId = userId;
  }

  @override
  Future<Profile> createProfile({required String displayName, String? avatarUrl}) async {
    final accountId = await _accountId();
    if (accountId == null) throw StateError('No account for the current user.');
    final row = await _client
        .from(_profiles)
        .insert({'account_id': accountId, 'display_name': displayName, if (avatarUrl != null) 'avatar_url': avatarUrl})
        .select()
        .single();
    return Profile.fromRow(row);
  }

  @override
  Future<Profile> updateProfile(String profileId, {String? displayName, String? avatarUrl}) async {
    final patch = <String, dynamic>{if (displayName != null) 'display_name': displayName, if (avatarUrl != null) 'avatar_url': avatarUrl};
    final row = await _client.from(_profiles).update(patch).eq('id', profileId).select().single();
    final profile = Profile.fromRow(row);
    if (_activeCache?.id == profileId) _activeCache = profile;
    return profile;
  }

  @override
  Future<String> uploadAvatar(String profileId, Uint8List bytes, {required String fileExtension}) async {
    final accountId = await _accountId();
    if (accountId == null) throw StateError('No account for the current user.');
    final path = '$accountId/$profileId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage.from(_avatarBucket).uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return _client.storage.from(_avatarBucket).getPublicUrl(path);
  }
}
