import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/system_bars_background.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
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
  await dotenv.load(fileName: 'assets/config/app.env');
  await AuthController.ensureInitialized();
  runApp(const _PopcornAndroidApp());
}

class _PopcornAndroidApp extends StatefulWidget {
  const _PopcornAndroidApp();

  @override
  State<_PopcornAndroidApp> createState() => _PopcornAndroidAppState();
}

class _PopcornAndroidAppState extends State<_PopcornAndroidApp> {
  final AppServices _services = AppServices.create();

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

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
      builder: (context, child) => SystemBarsBackground(
        child: AuthGate(
          controller: _services.authController,
          loginBuilder: (context) => MaterialLoginView(controller: _services.authController),
          child: child!,
        ),
      ),
      initialRoute: AppRoutes.home,
      onGenerateRoute: (settings) => _buildRoute(settings, AppRoutes.parse(settings.name)),
      onGenerateInitialRoutes: _initialRoutes,
    );
  }

  List<Route<dynamic>> _initialRoutes(String initialRoute) {
    final home = _buildRoute(const RouteSettings(name: AppRoutes.home), const HomeRoute());
    final request = AppRoutes.parse(initialRoute);
    if (request is HomeRoute || request is UnknownRoute || request is TrailerRoute) {
      return <Route<dynamic>>[home];
    }
    if (request is SearchRoute) {
      return <Route<dynamic>>[_buildRoute(RouteSettings(name: initialRoute), request)];
    }
    return <Route<dynamic>>[home, _buildRoute(RouteSettings(name: initialRoute), request)];
  }

  Route<dynamic> _buildRoute(RouteSettings settings, AppRouteRequest request) =>
      MaterialPageRoute<void>(settings: settings, builder: (context) => _pageFor(context, request, settings.arguments));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case HomeRoute():
      case UnknownRoute():
        return _AndroidHomeView(services: _services);
      case SearchRoute(:final query, :final type):
        return _AndroidHomeView(services: _services, initialQuery: query, initialMediaType: type);
      case FavoritesRoute():
        return _favoritesPage(context);
      case HistoryRoute():
        return _historyPage(context);
      case DetailsRoute(:final type, :final id):
        return _detailsPage(type, id, arguments is MediaItem ? arguments : null);
      case WatchRoute(:final type, :final id, :final season, :final episode):
        return _watchPage(type, id, season, episode, arguments is MediaItem ? arguments : null);
      case TrailerRoute():
        final video = arguments is MediaVideo ? arguments : null;
        return video == null ? _AndroidHomeView(services: _services) : _trailerPage(video);
    }
  }

  Widget _playerPage(Widget player) => PopcornMaterialSplashScreen(
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(child: player),
    ),
  );

  Widget _favoritesPage(BuildContext context) => PopcornMaterialSplashScreen(
    child: Scaffold(
      appBar: AppBar(title: Text(FavoritesTranslations.pageTitle.trOf(context))),
      body: SafeArea(
        child: MaterialFavoritesView(
          controller: _services.favoritesController,
          onMediaSelected: (favorite) => Navigator.of(context).pushNamed(AppRoutes.details(favorite.type, favorite.item.id), arguments: favorite.item),
        ),
      ),
    ),
  );

  Widget _historyPage(BuildContext context) => PopcornMaterialSplashScreen(
    child: Scaffold(
      appBar: AppBar(title: Text(WatchHistoryTranslations.pageTitle.trOf(context))),
      body: SafeArea(
        child: MaterialContinueWatchingView(
          controller: _services.historyController,
          onMediaSelected: (entry) => Navigator.of(context).pushNamed(AppRoutes.details(entry.type, entry.item.id), arguments: entry.item),
          onMediaPlay: (entry) => Navigator.of(context).pushNamed(
            AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
            arguments: entry.item,
          ),
        ),
      ),
    ),
  );

  Widget _watchPage(MediaType type, int id, int? season, int? episode, MediaItem? item) => MediaPlaybackScaffold(
    id: id,
    type: type,
    season: season,
    episode: episode,
    item: item,
    services: _services,
    loadingBuilder: (context) => _playerPage(const Center(child: CircularProgressIndicator())),
    builder: (context, source, item) => _playerPage(VideoPlayerFactory.create(source: source)),
  );

  Widget _trailerPage(MediaVideo video) => _playerPage(
    VideoPlayerFactory.create(
      source: MediaSource(url: video.embedUrl!, data: video.embedHtml),
    ),
  );

  Widget _detailsPage(MediaType type, int id, MediaItem? item) => MediaDetailsScaffold(
    id: id,
    type: type,
    item: item,
    repository: _services.repository,
    loadingBuilder: (context) => const PopcornMaterialSplashScreen(
      child: Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    errorBuilder: (context, error) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$error', textAlign: TextAlign.center),
        ),
      ),
    ),
    builder: (context, bundle) => PopcornMaterialSplashScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(bundle.item.title)),
        body: SafeArea(
          child: MaterialMediaDetailsView(
            item: bundle.item,
            details: bundle.details,
            videos: bundle.videos,
            favoritesController: _services.favoritesController,
            mediaType: bundle.type,
            onPlay: (playItem) => Navigator.of(context).pushNamed(AppRoutes.watch(bundle.type, playItem.id), arguments: playItem),
            onVideoPlay: (video) => Navigator.of(context).pushNamed(AppRoutes.trailer, arguments: video),
            episodesLoader: (season) => _services.repository.episodes(bundle.item.id, season.seasonNumber),
            onPlayEpisode: (season, episode) => Navigator.of(context).pushNamed(
              AppRoutes.watch(bundle.type, bundle.item.id, season: season.seasonNumber, episode: episode.episodeNumber),
              arguments: bundle.item,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AndroidHomeView extends StatelessWidget {
  const _AndroidHomeView({required this.services, this.initialQuery, this.initialMediaType});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  @override
  Widget build(BuildContext context) {
    return PopcornMaterialSplashScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(SearchTranslations.pageTitle.trOf(context)),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: WatchHistoryTranslations.pageTitle.trOf(context),
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            ),
            IconButton(
              icon: const Icon(Icons.favorite),
              tooltip: FavoritesTranslations.pageTitle.trOf(context),
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.favorites),
            ),
          ],
        ),
        body: MaterialMediaSearchView(
          controller: services.searchController,
          favoritesController: services.favoritesController,
          initialQuery: initialQuery,
          initialMediaType: initialMediaType,
          onMediaSelected: (media) => Navigator.of(context).pushNamed(AppRoutes.details(services.searchController.mediaType, media.id), arguments: media),
          onMediaPlay: (media) => Navigator.of(context).pushNamed(AppRoutes.watch(services.searchController.mediaType, media.id), arguments: media),
        ),
      ),
    );
  }
}
