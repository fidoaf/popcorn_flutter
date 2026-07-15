import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';

import 'src/app/view/web/splash_screen.dart';

void main(List<String> args) async {
  if (!kIsWeb) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const _PopcornWebApp());
}

class _PopcornWebApp extends StatelessWidget {
  const _PopcornWebApp();

  static const Color _background = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      color: _background,
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      home: const _WebHomeView(),
    );
  }
}

class _WebHomeView extends StatefulWidget {
  const _WebHomeView();

  @override
  State<_WebHomeView> createState() => _WebHomeViewState();
}

class _WebHomeViewState extends State<_WebHomeView> {
  late final MediaSearchController _searchController = MediaSearchController(repository: MediaSearchRepositoryFactory.create());

  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMedia(MediaItem media) {
    final mediaSegment = _searchController.mediaType == MediaType.tv ? 'tv' : 'movie';
    final source = Uri.parse('https://web.nxsha.app/embed/$mediaSegment/${media.id}?lang=en&sub=1');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornWebSplashScreen(
          child: Theme(
            data: _theme,
            child: Material(
              color: _PopcornWebApp._background,
              child: VideoPlayerFactory.create(source: source),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornWebSplashScreen(
      child: Theme(
        data: _theme,
        child: Material(
          color: _PopcornWebApp._background,
          child: SafeArea(
            child: MaterialMediaSearchView(controller: _searchController, onMediaSelected: _openMedia),
          ),
        ),
      ),
    );
  }
}
