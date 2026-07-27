import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
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
  final FavoritesController _favoritesController = FavoritesController(repository: FavoritesRepositoryFactory.create());

  @override
  void dispose() {
    _searchController.dispose();
    _favoritesController.dispose();
    super.dispose();
  }

  void _openMedia(MediaItem media) => _openMediaFor(media, _searchController.mediaType);

  void _openMediaFor(MediaItem media, MediaType type) {
    final source = _mediaSourceProvider.resolve(media, type);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!, data: video.embedHtml);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) => _openDetailsFor(media, _searchController.mediaType);

  void _openDetailsFor(MediaItem media, MediaType type) {
    final details = _repository.details(media.id, type);
    final videos = _repository.videos(media.id, type);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            appBar: AppBar(title: Text(media.title)),
            body: SafeArea(
              child: MaterialMediaDetailsView(
                item: media,
                details: details,
                videos: videos,
                favoritesController: _favoritesController,
                mediaType: type,
                onPlay: (item) => _openMediaFor(item, type),
                onVideoPlay: _playVideo,
                episodesLoader: (season) => _repository.episodes(media.id, season.seasonNumber),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            appBar: AppBar(title: Text(FavoritesTranslations.pageTitle.trOf(context))),
            body: SafeArea(
              child: MaterialFavoritesView(controller: _favoritesController, onMediaSelected: (favorite) => _openDetailsFor(favorite.item, favorite.type)),
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
        appBar: AppBar(
          title: Text(SearchTranslations.pageTitle.trOf(context)),
          actions: [IconButton(icon: const Icon(Icons.favorite), tooltip: FavoritesTranslations.pageTitle.trOf(context), onPressed: _openFavorites)],
        ),
        body: MaterialMediaSearchView(
          controller: _searchController,
          favoritesController: _favoritesController,
          onMediaSelected: _openDetails,
          onMediaPlay: _openMedia,
        ),
      ),
    );
  }
}
