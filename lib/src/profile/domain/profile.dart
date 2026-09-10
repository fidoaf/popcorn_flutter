/// A viewing profile within an account.
///
/// An account owns many profiles and any account member can switch between
/// them. Each profile keeps its own favorites and watch history.
final class Profile {
  const Profile({required this.id, required this.accountId, required this.displayName, this.avatarUrl});

  final String id;
  final String accountId;
  final String displayName;
  final String? avatarUrl;

  Profile copyWith({String? displayName, String? avatarUrl}) =>
      Profile(id: id, accountId: accountId, displayName: displayName ?? this.displayName, avatarUrl: avatarUrl ?? this.avatarUrl);

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    accountId: row['account_id'] as String,
    displayName: row['display_name'] as String? ?? 'Profile',
    avatarUrl: row['avatar_url'] as String?,
  );
}
