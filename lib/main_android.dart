import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/startup_error_app.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/landing_view.dart';
import 'package:popcorn_flutter/src/app/view/maintenance_page.dart';
import 'package:popcorn_flutter/src/app/view/system_bars_background.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
import 'package:popcorn_flutter/src/home/home.dart';
import 'package:popcorn_flutter/src/legal/legal.dart';
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
  await initializeDateFormatting();
  try {
    await AuthController.ensureInitialized();
    runApp(const _PopcornAndroidApp());
  } catch (error, stack) {
    runApp(StartupErrorApp(message: 'Unable to start the app. Please check your configuration.', details: '$error\n$stack'));
    // ignore: avoid_print
    print('Startup error: $error\n$stack');
  }
}

class _PopcornAndroidApp extends StatefulWidget {
  const _PopcornAndroidApp();

  @override
  State<_PopcornAndroidApp> createState() => _PopcornAndroidAppState();
}

class _PopcornAndroidAppState extends State<_PopcornAndroidApp> {
  AppServices? _servicesOrNull;
  Object? _startupError;
  AppServices get _services => _servicesOrNull!;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final String _initialLocation = PlatformDispatcher.instance.defaultRouteName;
  GoRouter? _router;
  RouterLocationListenable? _location;

  @override
  void initState() {
    super.initState();
    AppServices.create()
        .then((services) {
          if (!mounted) return;
          final router = createAppRouter(
            navigatorKey: _navigatorKey,
            pageBuilder: _buildPage,
            isSignedIn: () => services.authController.isSignedIn,
            initialLocation: _initialLocation,
          );
          setState(() {
            _servicesOrNull = services;
            _router = router;
            _location = RouterLocationListenable(router.routeInformationProvider);
          });
        })
        .catchError((Object error) {
          if (mounted) setState(() => _startupError = error);
        });
  }

  @override
  void dispose() {
    _location?.dispose();
    _router?.dispose();
    _servicesOrNull?.dispose();
    super.dispose();
  }

  Widget _bootstrapApp(Widget home) => MaterialApp(
    onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
    locale: PlatformDispatcher.instance.locale,
    supportedLocales: AppLanguage.values.map((lang) => lang.locale),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    themeMode: ThemeMode.system,
    theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark),
    home: home,
  );

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) return _bootstrapApp(const MaintenancePage());
    if (_servicesOrNull == null || _router == null) return _bootstrapApp(const PopcornMaterialSplashScreen());
    return MaterialApp.router(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark),
      routerConfig: _router!,
      builder: (context, child) => SystemBarsBackground(
        child: AuthGate(
          controller: _services.authController,
          currentRoute: _location,
          isPublicRoute: AppRoutes.isPublic,
          loginBuilder: (context) => MaterialLoginView(
            controller: _services.authController,
            onOpenPrivacy: () => _router!.push(AppRoutes.privacy),
            onOpenTerms: () => _router!.push(AppRoutes.terms),
          ),
          child: child!,
        ),
      ),
    );
  }

  Page<void> _buildPage(BuildContext context, GoRouterState state, AppRouteRequest request) =>
      MaterialPage<void>(key: state.pageKey, child: _pageFor(context, request, state.extra));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _AndroidHomeView(services: _services, browse: true);
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
        return video == null ? _AndroidHomeView(services: _services, browse: true) : _trailerPage(video);
      case PrivacyRoute():
        return _legalPage(context, LegalTranslations.privacyPolicy);
      case TermsRoute():
        return _legalPage(context, LegalTranslations.termsOfService);
    }
  }

  Widget _legalPage(BuildContext context, LegalDocument document) => PopcornMaterialSplashScreen(
    child: Scaffold(
      appBar: AppBar(title: Text(document.title.trOf(context))),
      body: SafeArea(child: LegalDocumentView(document: document)),
    ),
  );

  Widget _landingPage(BuildContext context) => PopcornMaterialSplashScreen(
    child: PopcornLandingView(
      onEnter: () => context.go(AppRoutes.home),
      onOpenPrivacy: () => context.push(AppRoutes.privacy),
      onOpenTerms: () => context.push(AppRoutes.terms),
    ),
  );

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
          onMediaSelected: (favorite) => context.push(AppRoutes.details(favorite.type, favorite.item.id), extra: favorite.item),
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
          onMediaSelected: (entry) => context.push(AppRoutes.details(entry.type, entry.item.id), extra: entry.item),
          onMediaPlay: (entry) => context.push(
            AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
            extra: entry.item,
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
            related: bundle.related,
            favoritesController: _services.favoritesController,
            historyController: _services.historyController,
            mediaType: bundle.type,
            mediaSourceProvider: _services.mediaSourceProvider,
            onPlay: (playItem) => context.push(AppRoutes.watch(bundle.type, playItem.id), extra: playItem),
            onResume: (playItem, {season, episode}) => context.push(
              AppRoutes.watch(bundle.type, playItem.id, season: season, episode: episode),
              extra: playItem,
            ),
            onVideoPlay: (video) => context.push(AppRoutes.trailer, extra: video),
            onRelatedSelected: (related) => context.push(AppRoutes.details(bundle.type, related.id), extra: related),
            episodesLoader: (season) => _services.repository.episodes(bundle.item.id, season.seasonNumber),
            onPlayEpisode: (season, episode) => context.push(
              AppRoutes.watch(bundle.type, bundle.item.id, season: season.seasonNumber, episode: episode.episodeNumber),
              extra: bundle.item,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AndroidHomeView extends StatelessWidget {
  const _AndroidHomeView({required this.services, this.initialQuery, this.initialMediaType, this.browse = false});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  /// When `true`, shows the streaming-style browse home instead of the
  /// search-first view.
  final bool browse;

  @override
  Widget build(BuildContext context) {
    final showLabels = MediaQuery.sizeOf(context).width >= 600;
    return PopcornMaterialSplashScreen(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabels)
                TextButton.icon(
                  icon: const Icon(Icons.history),
                  label: Text(WatchHistoryTranslations.pageTitle.trOf(context)),
                  onPressed: () => context.push(AppRoutes.history),
                )
              else
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: WatchHistoryTranslations.pageTitle.trOf(context),
                  onPressed: () => context.push(AppRoutes.history),
                ),
              const SizedBox(width: 4),
              if (showLabels)
                TextButton.icon(
                  icon: const Icon(Icons.favorite),
                  label: Text(FavoritesTranslations.pageTitle.trOf(context)),
                  onPressed: () => context.push(AppRoutes.favorites),
                )
              else
                IconButton(
                  icon: const Icon(Icons.favorite),
                  tooltip: FavoritesTranslations.pageTitle.trOf(context),
                  onPressed: () => context.push(AppRoutes.favorites),
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: UserIdentityTitle(
                controller: services.authController,
                profileController: services.profileController,
                fallbackTitle: Text(SearchTranslations.pageTitle.trOf(context)),
              ),
            ),
          ],
        ),
        body: browse
            ? BrowseHomeView(
                feedController: services.homeFeedController,
                favoritesController: services.favoritesController,
                historyController: services.historyController,
                searchController: services.searchController,
                onOpenDetails: (media, type) => context.push(AppRoutes.details(type, media.id), extra: media),
                onPlay: (media, type) => context.push(AppRoutes.watch(type, media.id), extra: media),
                onResume: (entry) => context.push(
                  AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
                  extra: entry.item,
                ),
                onSeeAllFavorites: () => context.push(AppRoutes.favorites),
                onSeeAllHistory: () => context.push(AppRoutes.history),
              )
            : MaterialMediaSearchView(
                controller: services.searchController,
                favoritesController: services.favoritesController,
                initialQuery: initialQuery,
                initialMediaType: initialMediaType,
                onMediaSelected: (media) => context.push(AppRoutes.details(services.searchController.mediaType, media.id), extra: media),
                onMediaPlay: (media) => context.push(AppRoutes.watch(services.searchController.mediaType, media.id), extra: media),
              ),
      ),
    );
  }
}
