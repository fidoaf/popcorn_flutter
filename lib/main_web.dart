import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final MediaSearchRepository _repository = MediaSearchRepositoryFactory.create();
  late final MediaSearchController _searchController = MediaSearchController(repository: _repository);
  final ConfigurableMediaSourceProvider _mediaSourceProvider = MediaSourceProviderFactory.create();
  final FavoritesController _favoritesController = FavoritesController(repository: FavoritesRepositoryFactory.create());

  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark);

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

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!);
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

  void _openDetails(MediaItem media) => _openDetailsFor(media, _searchController.mediaType);

  void _openDetailsFor(MediaItem media, MediaType type) {
    final details = _repository.details(media.id, type);
    final videos = _repository.videos(media.id, type);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornWebSplashScreen(
          child: Theme(
            data: _theme,
            child: Material(
              color: _PopcornWebApp._background,
              child: SafeArea(
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
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornWebSplashScreen(
          child: Theme(
            data: _theme,
            child: Scaffold(
              backgroundColor: _PopcornWebApp._background,
              appBar: AppBar(backgroundColor: _PopcornWebApp._background, title: Text(FavoritesTranslations.pageTitle.trOf(context))),
              body: SafeArea(
                child: MaterialFavoritesView(
                  controller: _favoritesController,
                  onMediaSelected: (favorite) => _openDetailsFor(favorite.item, favorite.type),
                ),
              ),
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
        child: Scaffold(
          backgroundColor: _PopcornWebApp._background,
          appBar: AppBar(
            backgroundColor: _PopcornWebApp._background,
            title: Text(SearchTranslations.pageTitle.trOf(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite),
                tooltip: FavoritesTranslations.pageTitle.trOf(context),
                onPressed: _openFavorites,
              ),
            ],
          ),
          body: SafeArea(
            child: MaterialMediaSearchView(
              controller: _searchController,
              favoritesController: _favoritesController,
              onMediaSelected: _openDetails,
              onMediaPlay: _openMedia,
            ),
          ),
        ),
      ),
    );
  }
}
