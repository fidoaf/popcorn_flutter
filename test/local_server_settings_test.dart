import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/infrastructure/local_server_preference.dart';
import 'package:popcorn_flutter/src/profile/view/account_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('local server setting is ${platform == TargetPlatform.windows ? 'opt-in on Windows' : 'hidden on other platforms'}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        platform == TargetPlatform.windows
            ? const fluent.FluentApp(home: fluent.ScaffoldPage(content: AccountSettingsView()))
            : const MaterialApp(home: Scaffold(body: AccountSettingsView())),
      );
      await tester.pumpAndSettle();
      if (platform == TargetPlatform.windows) {
        final toggle = find.byType(SwitchListTile);
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(await LocalServerPreference.isEnabled(), isTrue);
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
        expect(find.textContaining('Restart the app'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(await LocalServerPreference.isEnabled(), isFalse);
      } else {
        expect(find.byType(SwitchListTile), findsNothing);
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
