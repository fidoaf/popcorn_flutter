import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

import 'src/app/view/material/splash_screen.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  runApp(const _PopcornAndroidApp());
}

class _PopcornAndroidApp extends StatelessWidget {
  const _PopcornAndroidApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark),
      home: const _AndroidHomeView(),
    );
  }
}

class _AndroidHomeView extends StatelessWidget {
  const _AndroidHomeView();

  @override
  Widget build(BuildContext context) {
    return const PopcornMaterialSplashScreen();
  }
}
