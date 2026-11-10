import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/infrastructure/local_server_preference.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_factory.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_preference.dart';
import 'package:popcorn_flutter/src/profile/view/account_settings_view.dart';
import 'package:popcorn_flutter/src/profile/view/player_settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _providerConfig() => {
  'initialProvider': 'Render',
  'providers': [
    {'name': 'Render', 'host': 'popcorn-flutter.onrender.com', 'path': '/player'},
    {'name': 'External', 'host': 'external.example', 'path': '/embed/{type}/{id}'},
  ],
};

void main() {
  testWidgets('player settings retains the account page theme across navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.deepOrange);
    const background = Color(0xFF1A1A2E);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Theme(
          data: theme,
          child: Scaffold(
            backgroundColor: background,
            body: AccountSettingsView(mediaSourceProvider: MediaSourceProviderFactory.createFromMap(_providerConfig(), playerServerToken: '')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Player's settings"));
    await tester.pumpAndSettle();
    final pageContext = tester.element(find.byType(PlayerSettingsView));
    expect(Theme.of(pageContext).brightness, Brightness.dark);
    expect(Theme.of(pageContext).colorScheme, theme.colorScheme);
    expect(Theme.of(pageContext).scaffoldBackgroundColor, theme.scaffoldBackgroundColor);
    final pageScaffold = find.descendant(of: find.byType(PlayerSettingsView), matching: find.byType(Scaffold));
    final pageAppBar = find.descendant(of: find.byType(PlayerSettingsView), matching: find.byType(AppBar));
    expect(tester.widget<Scaffold>(pageScaffold).backgroundColor, background);
    expect(tester.widget<AppBar>(pageAppBar).backgroundColor, background);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('local server setting is ${platform == TargetPlatform.windows ? 'opt-in on Windows' : 'hidden on other platforms'}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mediaSourceProvider = MediaSourceProviderFactory.createFromMap(_providerConfig(), playerServerToken: '');
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        platform == TargetPlatform.windows
            ? fluent.FluentApp(
                home: fluent.ScaffoldPage(content: AccountSettingsView(mediaSourceProvider: mediaSourceProvider)),
              )
            : MaterialApp(
                home: Scaffold(body: AccountSettingsView(mediaSourceProvider: mediaSourceProvider)),
              ),
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

  testWidgets('media provider setting switches delegate and persists selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mediaSourceProvider = MediaSourceProviderFactory.createFromMap(_providerConfig(), playerServerToken: '');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountSettingsView(mediaSourceProvider: mediaSourceProvider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(mediaSourceProvider.delegate.name, 'Render');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('External').last);
    await tester.pumpAndSettle();

    expect(mediaSourceProvider.delegate.name, 'External');
    expect(await MediaSourceProviderPreference.selectedProviderName(), 'External');
  });
}
