import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/fluent/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  await dotenv.load();
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

class _WindowsHomeView extends StatefulWidget {
  const _WindowsHomeView();

  @override
  State<_WindowsHomeView> createState() => _WindowsHomeViewState();
}

class _WindowsHomeViewState extends State<_WindowsHomeView> {
  late final MovieSearchController _searchController = MovieSearchController(repository: MovieSearchRepositoryFactory.create());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMovie(Movie movie) {
    final source = Uri.parse('https://web.nxsha.app/embed/movie/${movie.id}?lang=en&sub=1');
    Navigator.of(context).push(
      FluentPageRoute<void>(
        builder: (_) => PopcornFluentSplashScreen(child: VideoPlayerFactory.create(source: source)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornFluentSplashScreen(
      child: FluentMovieSearchView(controller: _searchController, onMovieSelected: _openMovie),
    );
  }
}
