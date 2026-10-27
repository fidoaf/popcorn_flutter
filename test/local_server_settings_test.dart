import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/infrastructure/local_server_preference.dart';
import 'package:popcorn_flutter/src/profile/view/account_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('migrates the previous Windows local-server preference', () async {
    SharedPreferences.setMockInitialValues({'windows.localPlayerServer': true});
    expect(await LocalServerPreference.isEnabled(), isTrue);

    await LocalServerPreference.setEnabled(false);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('player.localServer'), isFalse);
    expect(preferences.containsKey('windows.localPlayerServer'), isFalse);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('local server setting is opt-in on ${platform.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        platform == TargetPlatform.windows
            ? const fluent.FluentApp(home: fluent.ScaffoldPage(content: AccountSettingsView()))
            : const MaterialApp(home: Scaffold(body: AccountSettingsView())),
      );
      await tester.pumpAndSettle();
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await LocalServerPreference.isEnabled(), isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.textContaining('Restart to apply'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await LocalServerPreference.isEnabled(), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
