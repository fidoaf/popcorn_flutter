import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/fluent/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:window_manager/window_manager.dart'; // NOT material.dart

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  await windowManager.ensureInitialized();
  const WindowOptions windowOptions = WindowOptions(title: 'Popcorn', center: true, size: Size(800, 600));
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const _PopcornWindowsApp(home: _WindowsHomeView()));
}

class _PopcornWindowsApp extends StatelessWidget {
  final Widget home;
  const _PopcornWindowsApp({required this.home});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      themeMode: ThemeMode.system,
      theme: FluentThemeData.light(),
      darkTheme: FluentThemeData.dark(),
      home: home,
    );
  }
}

class _WindowsHomeView extends StatelessWidget {
  const _WindowsHomeView();

  @override
  Widget build(BuildContext context) {
    return const PopcornFluentSplashScreen();
  }
}
