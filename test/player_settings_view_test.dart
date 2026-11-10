import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/profile/view/player_settings_view.dart';

void main() {
  testWidgets('loads and saves server provider settings with bearer auth', (tester) async {
    final initial = {
      'initialProvider': 'Example',
      'providers': [
        {
          'name': 'Example',
          'host': 'example.test',
          'path': '/embed/{id}',
          'parameters': {'lang': '{language}'},
          'headers': {'Referer': 'https://example.test/'},
          'cookies': [
            {'name': 'session', 'value': 'example'},
          ],
          'sandbox': false,
          'customSetting': 'preserved',
        },
      ],
    };
    var saved = false;
    final client = MockClient((request) async {
      expect(request.url, Uri.https('player.example', '/settings'));
      expect(request.headers['authorization'], 'Bearer test-token');
      if (request.method == 'GET') return http.Response(jsonEncode(initial), 200);
      expect(request.method, 'PUT');
      final expected = jsonDecode(jsonEncode(initial)) as Map<String, dynamic>;
      (expected['providers'] as List).first['host'] = 'updated.test';
      (expected['providers'] as List).first['parameters'] = {'language': 'en'};
      expect(jsonDecode(request.body), expected);
      saved = true;
      return http.Response(request.body, 200);
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSettingsView(endpoint: Uri.https('player.example', '/settings'), token: 'test-token', client: client),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Player's settings"), findsOneWidget);
    expect(find.ancestor(of: find.text('example.test'), matching: find.byType(Card)), findsOneWidget);
    expect(find.byKey(const ValueKey('player-settings-config')), findsNothing);
    await tester.tap(find.text('Example').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('provider-0-host')), 'updated.test');
    await tester.ensureVisible(find.byKey(const ValueKey('provider-0-parameters')));
    await tester.tap(find.text('parameters'));
    await tester.pumpAndSettle();
    final keyField = find.widgetWithText(TextFormField, 'lang');
    await tester.ensureVisible(keyField);
    await tester.enterText(keyField, 'language');
    final valueField = find.widgetWithText(TextFormField, '{language}');
    await tester.ensureVisible(valueField);
    await tester.enterText(valueField, 'en');
    await tester.tap(find.byKey(const ValueKey('player-settings-save')));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('Player settings saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects empty provider hosts without sending an update', (tester) async {
    var updates = 0;
    final client = MockClient((request) async {
      if (request.method == 'PUT') updates++;
      return http.Response(
        jsonEncode({
          'initialProvider': 'Example',
          'providers': [
            {'name': 'Example', 'host': 'example.test'},
          ],
        }),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerSettingsView(endpoint: Uri.https('player.example', '/settings'), token: 'test-token', client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Example').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('provider-0-host')), '');
    await tester.tap(find.byKey(const ValueKey('player-settings-save')));
    await tester.pumpAndSettle();
    expect(updates, 0);
    expect(find.text('Required'), findsOneWidget);
  });
}
