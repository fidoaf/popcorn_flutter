import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/admin/push_notification_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Future<void> showForm(WidgetTester tester, Future<PushSendResult> Function(String, String, String) send) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PushNotificationForm(onSend: send)),
      ),
    );
  }

  Future<void> fillForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  New movies  ');
    await tester.enterText(fields.at(1), '  Discover the latest releases.  ');
    await tester.enterText(fields.at(2), '  #/home  ');
  }

  Future<void> startSending(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Send to all subscribed browsers'));
    await tester.tap(find.text('Send to all subscribed browsers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('rejects malformed result counts rather than reporting success', () {
    for (final data in [
      null,
      {'sent': '1', 'failed': 0, 'removed': 0},
      {'sent': -1, 'failed': 0, 'removed': 0},
      {'sent': 1, 'failed': 0},
    ]) {
      expect(() => PushSendResult.fromJson(data), throwsFormatException);
    }
    expect(PushSendResult.fromJson({'sent': 2, 'failed': 1, 'removed': 3}).sent, 2);
  });

  testWidgets('signed-out admin must sign in before sending', (tester) async {
    final client = (await tester.runAsync(
      () async => SupabaseClient('https://example.supabase.co', 'public-key', authOptions: const AuthClientOptions(autoRefreshToken: false)),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PushNotificationPanel(client: client)),
      ),
    );
    expect(find.text('Sign in with Google to send push notifications'), findsOneWidget);
    expect(find.byType(PushNotificationForm), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });

  testWidgets('requires a title and message before confirmation', (tester) async {
    var calls = 0;
    await showForm(tester, (_, _, _) async {
      calls++;
      return const PushSendResult(sent: 1, failed: 0, removed: 0);
    });
    await startSending(tester);
    expect(find.text('Title is required.'), findsOneWidget);
    expect(find.text('Message is required.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, 0);
  });

  testWidgets('cancel does not broadcast', (tester) async {
    var calls = 0;
    await showForm(tester, (_, _, _) async {
      calls++;
      return const PushSendResult(sent: 1, failed: 0, removed: 0);
    });
    await fillForm(tester);
    await startSending(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('New movies'), findsNothing);
    expect(find.text('  New movies  '), findsOneWidget);
  });

  testWidgets('broadcasts trimmed content once and shows partial failures', (tester) async {
    final pending = Completer<PushSendResult>();
    var calls = 0;
    await showForm(tester, (title, body, url) {
      calls++;
      expect(title, 'New movies');
      expect(body, 'Discover the latest releases.');
      expect(url, '#/home');
      return pending.future;
    });
    await fillForm(tester);
    await startSending(tester);
    await tester.tap(find.text('Send now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed, isNull);
    pending.complete(const PushSendResult(sent: 2, failed: 1, removed: 3));
    await tester.pumpAndSettle();
    expect(find.text('Accepted by push services: 2. Failed: 1. Expired subscriptions removed: 3.'), findsOneWidget);
  });

  testWidgets('reports no subscribers explicitly', (tester) async {
    await showForm(tester, (_, _, _) async => const PushSendResult(sent: 0, failed: 0, removed: 0));
    await fillForm(tester);
    await startSending(tester);
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(find.text('No subscribed browsers. No notifications were sent.'), findsOneWidget);
  });

  testWidgets('reports function errors and retains the message', (tester) async {
    await showForm(tester, (_, _, _) async => throw const FunctionException(status: 403, details: 'Admin access is required.'));
    await fillForm(tester);
    await startSending(tester);
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to complete broadcast:'), findsOneWidget);
    expect(find.text('  Discover the latest releases.  '), findsOneWidget);
  });
}
