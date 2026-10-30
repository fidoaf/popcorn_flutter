import 'package:popcorn_flutter/src/profile/domain/home_section.dart';

/// A viewing profile within an account.
///
/// An account owns many profiles and any account member can switch between
/// them. Each profile keeps its own favorites and watch history.
final class Profile {
  const Profile({required this.id, required this.accountId, required this.displayName, this.avatarUrl, this.homeSections});

  final String id;
  final String accountId;
  final String displayName;
  final String? avatarUrl;
  final List<HomeSection>? homeSections;

  Profile copyWith({String? displayName, String? avatarUrl, List<HomeSection>? homeSections}) => Profile(
    id: id,
    accountId: accountId,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    homeSections: homeSections ?? this.homeSections,
  );

  factory Profile.fromRow(Map<String, dynamic> row) {
    final storedSections = row['home_sections'];
    return Profile(
      id: row['id'] as String,
      accountId: row['account_id'] as String,
      displayName: row['display_name'] as String? ?? 'Profile',
      avatarUrl: row['avatar_url'] as String?,
      homeSections: storedSections is List
          ? HomeSection.values.where((section) => storedSections.contains(section.databaseValue)).toList(growable: false)
          : null,
    );
  }
}
