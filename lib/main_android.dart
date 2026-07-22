import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
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
  // Allow the phone app to rotate freely between portrait and landscape.
  // Note: a partial set like [portraitUp, landscapeLeft, landscapeRight] makes
  // Flutter request SCREEN_ORIENTATION_USER_LANDSCAPE (landscape-locked, can't
  // return to portrait). Passing all four maps to SCREEN_ORIENTATION_FULL_USER,
  // which rotates both ways and respects the system rotation lock.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
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
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ),
            body: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ),
            body: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) {
    final details = _repository.details(media.id, _searchController.mediaType);
    final videos = _repository.videos(media.id, _searchController.mediaType);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            appBar: AppBar(title: Text(media.title)),
            body: SafeArea(
              child: MaterialMediaDetailsView(item: media, details: details, videos: videos, onPlay: _openMedia, onVideoPlay: _playVideo),
            ),
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
        body: MaterialMediaSearchView(controller: _searchController, onMediaSelected: _openDetails, onMediaPlay: _openMedia),
      ),
    );
  }
}
