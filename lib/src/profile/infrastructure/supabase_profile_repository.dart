import 'dart:typed_data';

import 'package:popcorn_flutter/src/profile/domain/profile.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [ProfileRepository] backed by Supabase (`profiles` and the `avatars` storage
/// bucket).
///
/// Each account member's default profile is stored server-side, so it follows
/// the authenticated user across devices without changing other members' defaults.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  static const String _profiles = 'profiles';
  static const String _members = 'account_members';
  static const String _avatarBucket = 'avatars';

  final SupabaseClient _client;
  Profile? _activeCache;
  String? _cacheUserId;
  String? _cacheAccountId;

  String? get _userId => _client.auth.currentUser?.id;

  Future<String?> _accountId() async {
    final userId = _userId;
    if (userId == null) return null;
    final member = await _client.from(_members).select('account_id').eq('user_id', userId).maybeSingle();
    return member?['account_id'] as String?;
  }

  Future<String?> _defaultProfileId(String userId) async {
    final member = await _client.from(_members).select('default_profile_id').eq('user_id', userId).maybeSingle();
    return member?['default_profile_id'] as String?;
  }

  @override
  Future<List<Profile>> listProfiles() async {
    final accountId = await _accountId();
    if (accountId == null) return const [];
    final rows = await _client.from(_profiles).select().eq('account_id', accountId).order('created_at');
    return rows.map(Profile.fromRow).toList();
  }

  @override
  Future<Profile?> activeProfile() async {
    final userId = _userId;
    if (userId == null) {
      _activeCache = null;
      _cacheUserId = null;
      _cacheAccountId = null;
      return null;
    }
    final accountId = await _accountId();
    if (accountId == null) {
      _activeCache = null;
      _cacheUserId = userId;
      _cacheAccountId = null;
      return null;
    }
    if (_activeCache != null && _cacheUserId == userId && _cacheAccountId == accountId) {
      return _activeCache;
    }

    Profile? profile;
    final defaultProfileId = await _defaultProfileId(userId);
    if (defaultProfileId != null) {
      final row = await _client.from(_profiles).select().eq('id', defaultProfileId).eq('account_id', accountId).maybeSingle();
      if (row != null) {
        profile = Profile.fromRow(row);
      }
    }
    // No valid default is present: use the account's first profile for this session.
    profile ??= await _firstProfileForAccount(accountId);

    _activeCache = profile;
    _cacheUserId = userId;
    _cacheAccountId = accountId;
    return profile;
  }

  Future<Profile?> _firstProfileForAccount(String accountId) async {
    final rows = await _client.from(_profiles).select().eq('account_id', accountId).order('created_at').limit(1);
    if (rows.isEmpty) return null;
    final profile = Profile.fromRow(rows.first);
    return profile;
  }

  @override
  Future<void> setActiveProfile(String profileId) async {
    final userId = _userId;
    if (userId == null) return;
    final accountId = await _accountId();
    if (accountId == null) return;
    final row = await _client.from(_profiles).select().eq('id', profileId).eq('account_id', accountId).maybeSingle();
    if (row == null) return;
    // Switching is session-local; keep the member's login default unchanged.
    _activeCache = Profile.fromRow(row);
    _cacheUserId = userId;
    _cacheAccountId = accountId;
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
