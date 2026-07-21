import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/fluent/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
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
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
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
  final MediaSearchRepository _repository = MediaSearchRepositoryFactory.create();
  late final MediaSearchController _searchController = MediaSearchController(repository: _repository);
  final ConfigurableMediaSourceProvider _mediaSourceProvider = MediaSourceProviderFactory.create();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMedia(MediaItem media) {
    final source = _mediaSourceProvider.resolve(media, _searchController.mediaType);
    Navigator.of(context).push(
      FluentPageRoute<void>(
        builder: (_) => _PopOnEscape(
          child: PopcornFluentSplashScreen(child: VideoPlayerFactory.create(source: source)),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) {
    final details = _repository.details(media.id, _searchController.mediaType);
    Navigator.of(context).push(
      FluentPageRoute<void>(
        builder: (_) => _PopOnEscape(
          child: PopcornFluentSplashScreen(
            child: FluentMediaDetailsView(item: media, details: details, onPlay: _openMedia),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornFluentSplashScreen(
      child: FluentMediaSearchView(controller: _searchController, onMediaSelected: _openDetails, onMediaPlay: _openMedia),
    );
  }
}

/// Pops the current route when the Escape key is pressed.
class _PopOnEscape extends StatelessWidget {
  const _PopOnEscape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
