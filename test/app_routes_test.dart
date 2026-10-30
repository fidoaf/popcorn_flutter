import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';

void main() {
  test('account settings route is recognized and requires sign-in', () {
    expect(
      AppRoutes.parse(AppRoutes.accountSettings),
      isA<AccountSettingsRoute>(),
    );
    expect(AppRoutes.isPublic(AppRoutes.accountSettings), isFalse);
  });

  test(
    'profile settings route is recognized separately and requires sign-in',
    () {
      expect(
        AppRoutes.parse(AppRoutes.profileSettings),
        isA<ProfileSettingsRoute>(),
      );
      expect(AppRoutes.isPublic(AppRoutes.profileSettings), isFalse);
    },
  );

  test('profile edit route retains the requested profile id', () {
    const profileId = 'profile-123';
    final request = AppRoutes.parse(AppRoutes.editProfile(profileId));

    expect(request, isA<ProfileSettingsRoute>());
    expect((request as ProfileSettingsRoute).profileId, profileId);
  });
}
