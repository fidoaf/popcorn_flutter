import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('provides an overlay to the login screen above the app navigator', (tester) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final controller = AuthController(client: client);
    const loginKey = ValueKey('login-screen');

    await tester.pumpWidget(
      MaterialApp(
        home: const SizedBox.shrink(),
        builder: (context, child) => AuthGate(
          controller: controller,
          loginBuilder: (context) => Builder(key: loginKey, builder: (_) => const SizedBox.shrink()),
          child: child!,
        ),
      ),
    );

    expect(Overlay.maybeOf(tester.element(find.byKey(loginKey))), isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await client.dispose();
  });
}
