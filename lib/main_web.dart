import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/landing_view.dart';
import 'package:popcorn_flutter/src/app/view/system_bars_background.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
import 'package:popcorn_flutter/src/legal/legal.dart';
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
  await dotenv.load(fileName: 'assets/config/app.env');
  await initializeDateFormatting();
  await AuthController.ensureInitialized();
  runApp(const _PopcornWebApp());
}

class _PopcornWebApp extends StatefulWidget {
  const _PopcornWebApp();

  static const Color _background = Color(0xFF1A1A2E);
  static final ThemeData _theme = ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true, brightness: Brightness.dark);

  @override
  State<_PopcornWebApp> createState() => _PopcornWebAppState();
}

class _PopcornWebAppState extends State<_PopcornWebApp> {
  final AppServices _services = AppServices.create();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final CurrentRouteObserver _routeObserver = CurrentRouteObserver(PlatformDispatcher.instance.defaultRouteName);

  Color get _background => _PopcornWebApp._background;
  ThemeData get _theme => _PopcornWebApp._theme;

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      color: _background,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      builder: (context, child) => SystemBarsBackground(
        backgroundColor: _background,
        child: AuthGate(
          controller: _services.authController,
          currentRoute: _routeObserver.routeName,
          isPublicRoute: AppRoutes.isPublic,
          loginBuilder: (context) => Theme(
            data: _theme,
            child: MaterialLoginView(
              controller: _services.authController,
              onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
              onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
            ),
          ),
          child: child!,
        ),
      ),
      initialRoute: AppRoutes.landing,
      onGenerateRoute: (settings) => _buildRoute(settings, AppRoutes.parse(settings.name)),
      onGenerateInitialRoutes: _initialRoutes,
    );
  }

  List<Route<dynamic>> _initialRoutes(String initialRoute) {
    final request = AppRoutes.parse(initialRoute);
    if (request is LandingRoute) {
      if (_services.authController.isSignedIn) {
        return <Route<dynamic>>[_buildRoute(const RouteSettings(name: AppRoutes.home), const HomeRoute())];
      }
      return <Route<dynamic>>[_buildRoute(const RouteSettings(name: AppRoutes.landing), const LandingRoute())];
    }
    final home = _buildRoute(const RouteSettings(name: AppRoutes.home), const HomeRoute());
    if (request is HomeRoute || request is UnknownRoute || request is TrailerRoute) {
      return <Route<dynamic>>[home];
    }
    if (request is SearchRoute) {
      return <Route<dynamic>>[_buildRoute(RouteSettings(name: initialRoute), request)];
    }
    return <Route<dynamic>>[home, _buildRoute(RouteSettings(name: initialRoute), request)];
  }

  Route<dynamic> _buildRoute(RouteSettings settings, AppRouteRequest request) {
    return PageRouteBuilder<void>(settings: settings, pageBuilder: (context, _, _) => _pageFor(context, request, settings.arguments));
  }

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _WebHomeView(services: _services);
      case SearchRoute(:final query, :final type):
        return _WebHomeView(services: _services, initialQuery: query, initialMediaType: type);
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
        return video == null ? _WebHomeView(services: _services) : _trailerPage(video);
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
      onEnter: () => _navigatorKey.currentState?.pushNamed(AppRoutes.home),
      onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
      onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
    ),
  );

  Widget _favoritesPage(BuildContext context) => _scaffoldPage(
    context,
    FavoritesTranslations.pageTitle.trOf(context),
    MaterialFavoritesView(
      controller: _services.favoritesController,
      onMediaSelected: (favorite) => Navigator.of(context).pushNamed(AppRoutes.details(favorite.type, favorite.item.id), arguments: favorite.item),
    ),
  );

  Widget _historyPage(BuildContext context) => _scaffoldPage(
    context,
    WatchHistoryTranslations.pageTitle.trOf(context),
    MaterialContinueWatchingView(
      controller: _services.historyController,
      onMediaSelected: (entry) => Navigator.of(context).pushNamed(AppRoutes.details(entry.type, entry.item.id), arguments: entry.item),
      onMediaPlay: (entry) => Navigator.of(context).pushNamed(
        AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
        arguments: entry.item,
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
    ),
  );
}

class _WebHomeView extends StatefulWidget {
  const _WebHomeView({required this.services, this.initialQuery, this.initialMediaType});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  @override
  State<_WebHomeView> createState() => _WebHomeViewState();
}

class _WebHomeViewState extends State<_WebHomeView> {
  String? _lastReportedUrl;

  @override
  void initState() {
    super.initState();
    widget.services.searchController.addListener(_syncUrl);
  }

  @override
  void dispose() {
    widget.services.searchController.removeListener(_syncUrl);
    super.dispose();
  }

  // Mirrors the running search into the browser address bar so it is shareable.
  void _syncUrl() {
    if (!mounted) return;
    // Only rewrite the URL while the search page is the visible route.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final controller = widget.services.searchController;
    final url = controller.query.isEmpty ? AppRoutes.home : AppRoutes.search(controller.query, type: controller.mediaType);
    if (url == _lastReportedUrl) return;
    _lastReportedUrl = url;
    SystemNavigator.routeInformationUpdated(uri: Uri.parse(url), replace: true);
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return PopcornWebSplashScreen(
      child: Theme(
        data: _PopcornWebApp._theme,
        child: Scaffold(
          backgroundColor: _PopcornWebApp._background,
          appBar: AppBar(
            backgroundColor: _PopcornWebApp._background,
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
          body: SafeArea(
            child: MaterialMediaSearchView(
              controller: services.searchController,
              favoritesController: services.favoritesController,
              initialQuery: widget.initialQuery,
              initialMediaType: widget.initialMediaType,
              onMediaSelected: (media) => Navigator.of(context).pushNamed(AppRoutes.details(services.searchController.mediaType, media.id), arguments: media),
              onMediaPlay: (media) => Navigator.of(context).pushNamed(AppRoutes.watch(services.searchController.mediaType, media.id), arguments: media),
            ),
          ),
        ),
      ),
    );
  }
}
