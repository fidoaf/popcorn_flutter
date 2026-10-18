import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';

void main() {
  test('account settings route is recognized and requires sign-in', () {
    expect(AppRoutes.parse(AppRoutes.accountSettings), isA<AccountSettingsRoute>());
    expect(AppRoutes.isPublic(AppRoutes.accountSettings), isFalse);
  });
}
