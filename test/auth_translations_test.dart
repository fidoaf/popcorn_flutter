import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final testCase in [
    (const Locale('es'), 'El correo electrónico o la contraseña no son correctos.'),
    (const Locale('ca', 'ES'), 'El correu electrònic o la contrasenya no són correctes.'),
    (const Locale('en'), 'Invalid email or password.'),
  ]) {
    testWidgets('translates invalid credentials for ${testCase.$1.languageCode}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: testCase.$1,
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ca', 'ES')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Builder(builder: (context) => Text(AuthTranslations.authenticationErrorFor(context, const AuthException('Invalid login credentials')))),
        ),
      );

      expect(find.text(testCase.$2), findsOneWidget);
      expect(find.text('Invalid login credentials'), findsNothing);
    });
  }

  testWidgets('uses a localized generic message for unknown auth errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es'), Locale('ca', 'ES')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: Builder(builder: (context) => Text(AuthTranslations.authenticationErrorFor(context, const AuthException('Unexpected provider error')))),
      ),
    );

    expect(find.text('No se pudo completar la autenticación. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Unexpected provider error'), findsNothing);
  });
}
