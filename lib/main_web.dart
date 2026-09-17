import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:popcorn_flutter/src/app/app.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/startup_error_app.dart';
import 'package:popcorn_flutter/src/app/update/web_update_checker.dart';
import 'package:popcorn_flutter/src/app/view/landing_view.dart';
import 'package:popcorn_flutter/src/app/view/maintenance_page.dart';
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

void main(List<String> args) async {
  if (!kIsWeb) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env');
  await initializeDateFormatting();
  try {
    await AuthController.ensureInitialized();
    runApp(const _PopcornWebApp());
  } catch (error, stack) {
    runApp(StartupErrorApp(message: 'Unable to start the app. Please check your configuration.', details: '$error\n$stack'));
    // ignore: avoid_print
    print('Startup error: $error\n$stack');
  }
}

class _PopcornWebApp extends StatefulWidget {
  const _PopcornWebApp();

  static const Color _background = Color(0xFF1A1A2E);
  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark);

  @override
  State<_PopcornWebApp> createState() => _PopcornWebAppState();
}

class _PopcornWebAppState extends State<_PopcornWebApp> with WidgetsBindingObserver {
  AppServices? _servicesOrNull;
  Object? _startupError;
  AppServices get _services => _servicesOrNull!;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  // Captured at startup before go_router reads it, so a deep-link reload survives.
  final String _initialLocation = PlatformDispatcher.instance.defaultRouteName;
  final WebUpdateChecker _updateChecker = WebUpdateChecker();
  GoRouter? _router;
  RouterLocationListenable? _location;

  Color get _background => _PopcornWebApp._background;
  ThemeData get _theme => _PopcornWebApp._theme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateChecker.start();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateChecker.checkNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateChecker.dispose();
    _location?.dispose();
    _router?.dispose();
    _servicesOrNull?.dispose();
    super.dispose();
  }

  Widget _bootstrapApp(Widget home) {
    // Render [home] for any route: on web the URL (e.g. /home on a signed-in
    // reload) drives the initial route, which a `home:`-only app can't resolve.
    Route<dynamic> route(RouteSettings settings) => PageRouteBuilder<void>(settings: settings, pageBuilder: (context, _, _) => home);
    return WidgetsApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      color: _background,
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      onGenerateRoute: route,
      onGenerateInitialRoutes: (_) => <Route<dynamic>>[route(const RouteSettings(name: AppRoutes.landing))],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) return _bootstrapApp(const MaintenancePage());
    if (_servicesOrNull == null || _router == null) return _bootstrapApp(const PopcornWebSplashScreen());
    return WidgetsApp.router(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      color: _background,
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      routerConfig: _router!,
      builder: (context, child) => WebUpdateBanner(
        checker: _updateChecker,
        child: SystemBarsBackground(
          backgroundColor: _background,
          child: AuthGate(
            controller: _services.authController,
            currentRoute: _location,
            isPublicRoute: AppRoutes.isPublic,
            loginBuilder: (context) => Theme(
              data: _theme,
              child: MaterialLoginView(
                controller: _services.authController,
                onOpenPrivacy: () => _router!.push(AppRoutes.privacy),
                onOpenTerms: () => _router!.push(AppRoutes.terms),
              ),
            ),
            child: child!,
          ),
        ),
      ),
    );
  }

  Page<void> _buildPage(BuildContext context, GoRouterState state, AppRouteRequest request) =>
      NoTransitionPage<void>(key: state.pageKey, child: _pageFor(context, request, state.extra));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _WebHomeView(services: _services, browse: true);
      case SearchRoute(:final query, :final type):
        return _WebHomeView(services: _services, browse: true, initialQuery: query, initialMediaType: type);
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
        return video == null ? _WebHomeView(services: _services, browse: true) : _trailerPage(video);
      case PrivacyRoute():
        return _legalPage(context, LegalTranslations.privacyPolicy);
      case TermsRoute():
        return _legalPage(context, LegalTranslations.termsOfService);
    }
  }

  Widget _scaffoldPage(BuildContext context, String title, Widget body) => PopcornWebSplashScreen(
    child: Theme(
      data: _theme,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(backgroundColor: _background, title: Text(title)),
        body: SafeArea(child: body),
      ),
    ),
  );

  Widget _playerShell(Widget player) => PopcornWebSplashScreen(
    child: Theme(
      data: _theme,
      child: Material(color: _background, child: player),
    ),
  );

  Widget _legalPage(BuildContext context, LegalDocument document) =>
      _scaffoldPage(context, document.title.trOf(context), LegalDocumentView(document: document));

  Widget _landingPage(BuildContext context) => PopcornWebSplashScreen(
    child: PopcornLandingView(
      onEnter: () => context.go(AppRoutes.home),
      onOpenPrivacy: () => context.push(AppRoutes.privacy),
      onOpenTerms: () => context.push(AppRoutes.terms),
    ),
  );

  Widget _favoritesPage(BuildContext context) => _scaffoldPage(
    context,
    FavoritesTranslations.pageTitle.trOf(context),
    MaterialFavoritesView(
      controller: _services.favoritesController,
      onMediaSelected: (favorite) => context.push(AppRoutes.details(favorite.type, favorite.item.id), extra: favorite.item),
    ),
  );

  Widget _historyPage(BuildContext context) => _scaffoldPage(
    context,
    WatchHistoryTranslations.pageTitle.trOf(context),
    MaterialContinueWatchingView(
      controller: _services.historyController,
      onMediaSelected: (entry) => context.push(AppRoutes.details(entry.type, entry.item.id), extra: entry.item),
      onMediaPlay: (entry) => context.push(
        AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
        extra: entry.item,
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
    loadingBuilder: (context) => _playerShell(const Center(child: CircularProgressIndicator())),
    builder: (context, source, item) => _playerShell(VideoPlayerFactory.create(source: source)),
  );

  Widget _trailerPage(MediaVideo video) => _playerShell(VideoPlayerFactory.create(source: MediaSource(url: video.embedUrl!)));

  Widget _detailsPage(MediaType type, int id, MediaItem? item) => MediaDetailsScaffold(
    id: id,
    type: type,
    item: item,
    repository: _services.repository,
    loadingBuilder: (context) => _playerShell(const Center(child: CircularProgressIndicator())),
    errorBuilder: (context, error) => _scaffoldPage(
      context,
      AppTranslations.appTitle.trOf(context),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$error', textAlign: TextAlign.center),
        ),
      ),
    ),
    builder: (context, bundle) => PopcornWebSplashScreen(
      child: Theme(
        data: _theme,
        child: Material(
          color: _background,
          child: SafeArea(
            child: MaterialMediaDetailsView(
              item: bundle.item,
              details: bundle.details,
              videos: bundle.videos,
              related: bundle.related,
              favoritesController: _services.favoritesController,
              historyController: _services.historyController,
              mediaType: bundle.type,
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
    ),
  );
}

class _WebHomeView extends StatefulWidget {
  const _WebHomeView({required this.services, this.initialQuery, this.initialMediaType, this.browse = false});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  /// When `true`, shows the streaming-style browse home instead of the
  /// search-first view.
  final bool browse;

  @override
  State<_WebHomeView> createState() => _WebHomeViewState();
}

class _WebHomeViewState extends State<_WebHomeView> {
  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final showLabels = MediaQuery.sizeOf(context).width >= 600;
    return PopcornWebSplashScreen(
      child: Theme(
        data: _PopcornWebApp._theme,
        child: Scaffold(
          backgroundColor: _PopcornWebApp._background,
          appBar: AppBar(
            backgroundColor: _PopcornWebApp._background,
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
          body: SafeArea(
            child: widget.browse
                ? BrowseHomeView(
                    feedController: services.homeFeedController,
                    favoritesController: services.favoritesController,
                    historyController: services.historyController,
                    searchController: services.searchController,
                    initialQuery: widget.initialQuery,
                    initialMediaType: widget.initialMediaType,
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
                    initialQuery: widget.initialQuery,
                    initialMediaType: widget.initialMediaType,
                    onMediaSelected: (media) => context.push(AppRoutes.details(services.searchController.mediaType, media.id), extra: media),
                    onMediaPlay: (media) => context.push(AppRoutes.watch(services.searchController.mediaType, media.id), extra: media),
                  ),
          ),
        ),
      ),
    );
  }
}
