import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';

import 'src/app/view/material/splash_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  await dotenv.load();
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
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark),
      home: const _AndroidHomeView(),
    );
  }
}

class _AndroidHomeView extends StatefulWidget {
  const _AndroidHomeView();

  @override
  State<_AndroidHomeView> createState() => _AndroidHomeViewState();
}

class _AndroidHomeViewState extends State<_AndroidHomeView> {
  late final MediaSearchController _searchController = MediaSearchController(repository: MediaSearchRepositoryFactory.create());

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
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            body: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornMaterialSplashScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(SearchTranslations.pageTitle.trOf(context))),
        body: MaterialMediaSearchView(controller: _searchController, onMediaSelected: _openMedia),
      ),
    );
  }
}
