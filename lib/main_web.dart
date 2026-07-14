import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

import 'src/app/view/web/splash_screen.dart';

void main(List<String> args) {
  if (!kIsWeb) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  runApp(const _PopcornWebApp());
}

class _PopcornWebApp extends StatelessWidget {
  const _PopcornWebApp();

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      color: const Color(0xFF1A1A2E),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      builder: (context, child) => const _WebHomeView(),
    );
  }
}

class _WebHomeView extends StatelessWidget {
  const _WebHomeView();

  @override
  Widget build(BuildContext context) {
    return const PopcornWebSplashScreen();
  }
}
