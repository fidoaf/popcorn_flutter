import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/fluent/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/landing_view.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  await dotenv.load(fileName: 'assets/config/app.env');
  await initializeDateFormatting();
  await AuthController.ensureInitialized();
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedBounds = _WindowStatePersistence.readBounds(prefs);
  final wasMaximized = _WindowStatePersistence.readMaximized(prefs);
  final WindowOptions windowOptions = WindowOptions(title: 'Popcorn', center: savedBounds == null, size: savedBounds?.size ?? const Size(800, 600));
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (savedBounds != null) {
      await windowManager.setBounds(savedBounds);
    }
    if (wasMaximized) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });
  windowManager.addListener(_WindowStatePersistence(prefs));
  runApp(const _PopcornWindowsApp());
}

/// Persists the window position, size and maximized state across launches.
class _WindowStatePersistence extends WindowListener {
  _WindowStatePersistence(this._prefs);

  static const String _keyX = 'window_x';
  static const String _keyY = 'window_y';
  static const String _keyWidth = 'window_width';
  static const String _keyHeight = 'window_height';
  static const String _keyMaximized = 'window_maximized';

  final SharedPreferences _prefs;

  static Rect? readBounds(SharedPreferences prefs) {
    final width = prefs.getDouble(_keyWidth);
    final height = prefs.getDouble(_keyHeight);
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    if (width == null || height == null || x == null || y == null) {
      return null;
    }
    return Rect.fromLTWH(x, y, width, height);
  }

  static bool readMaximized(SharedPreferences prefs) => prefs.getBool(_keyMaximized) ?? false;

  Future<void> _saveState() async {
    final isMaximized = await windowManager.isMaximized();
    await _prefs.setBool(_keyMaximized, isMaximized);
    // Keep the last non-maximized bounds so restoring from maximized works.
    if (isMaximized) return;
    final bounds = await windowManager.getBounds();
    await _prefs.setDouble(_keyX, bounds.left);
    await _prefs.setDouble(_keyY, bounds.top);
    await _prefs.setDouble(_keyWidth, bounds.width);
    await _prefs.setDouble(_keyHeight, bounds.height);
  }

  @override
  void onWindowResized() => _saveState();

  @override
  void onWindowMoved() => _saveState();

  @override
  void onWindowMaximize() => _saveState();

  @override
  void onWindowUnmaximize() => _saveState();

  @override
  void onWindowClose() => _saveState();
}

class _PopcornWindowsApp extends StatefulWidget {
  const _PopcornWindowsApp();

  @override
  State<_PopcornWindowsApp> createState() => _PopcornWindowsAppState();
}

class _PopcornWindowsAppState extends State<_PopcornWindowsApp> {
  final AppServices _services = AppServices.create();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final CurrentRouteObserver _routeObserver = CurrentRouteObserver(PlatformDispatcher.instance.defaultRouteName);

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: FluentThemeData.light(),
      darkTheme: FluentThemeData.dark(),
      builder: (context, child) => AuthGate(
        controller: _services.authController,
        currentRoute: _routeObserver.routeName,
        isPublicRoute: AppRoutes.isPublic,
        loginBuilder: (context) => FluentLoginView(
          controller: _services.authController,
          onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
          onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
        ),
        child: child!,
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

  Route<dynamic> _buildRoute(RouteSettings settings, AppRouteRequest request) =>
      FluentPageRoute<void>(settings: settings, builder: (context) => _pageFor(context, request, settings.arguments));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _WindowsHomeView(services: _services);
      case SearchRoute(:final query, :final type):
        return _WindowsHomeView(services: _services, initialQuery: query, initialMediaType: type);
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
        return video == null ? _WindowsHomeView(services: _services) : _trailerPage(video);
      case PrivacyRoute():
        return _legalPage(context, LegalTranslations.privacyPolicy);
      case TermsRoute():
        return _legalPage(context, LegalTranslations.termsOfService);
    }
  }

  Widget _legalPage(BuildContext context, LegalDocument document) => _PopOnEscape(
    child: PopcornFluentSplashScreen(
      child: ScaffoldPage(
        header: PageHeader(
          leading: IconButton(icon: const Icon(FluentIcons.back), onPressed: () => Navigator.of(context).pop()),
          title: Text(document.title.trOf(context)),
        ),
        content: LegalDocumentView(document: document),
      ),
    ),
  );

  Widget _landingPage(BuildContext context) => PopcornFluentSplashScreen(
    child: PopcornLandingView(
      onEnter: () => _navigatorKey.currentState?.pushReplacementNamed(AppRoutes.home),
      onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
      onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
    ),
  );

  Widget _playerPage(BuildContext context, Widget player) => _PopOnEscape(
    child: PopcornFluentSplashScreen(
      child: Stack(
        children: [
          player,
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(icon: const Icon(FluentIcons.chrome_close), onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    ),
  );

  Widget _favoritesPage(BuildContext context) => _PopOnEscape(
    child: PopcornFluentSplashScreen(
      child: FluentFavoritesView(
        controller: _services.favoritesController,
        onMediaSelected: (favorite) => Navigator.of(context).pushNamed(AppRoutes.details(favorite.type, favorite.item.id), arguments: favorite.item),
      ),
    ),
  );

  Widget _historyPage(BuildContext context) => _PopOnEscape(
    child: PopcornFluentSplashScreen(
      child: FluentContinueWatchingView(
        controller: _services.historyController,
        onMediaSelected: (entry) => Navigator.of(context).pushNamed(AppRoutes.details(entry.type, entry.item.id), arguments: entry.item),
        onMediaPlay: (entry) => Navigator.of(context).pushNamed(
          AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
          arguments: entry.item,
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
    loadingBuilder: (context) => _playerPage(context, const Center(child: ProgressRing())),
    builder: (context, source, resolved) => _playerPage(context, VideoPlayerFactory.create(source: source)),
  );

  Widget _trailerPage(MediaVideo video) => Builder(
    builder: (context) => _playerPage(
      context,
      VideoPlayerFactory.create(
        source: MediaSource(url: video.embedUrl!, data: video.embedHtml),
      ),
    ),
  );

  Widget _detailsPage(MediaType type, int id, MediaItem? item) => MediaDetailsScaffold(
    id: id,
    type: type,
    item: item,
    repository: _services.repository,
    loadingBuilder: (context) => const _PopOnEscape(
      child: PopcornFluentSplashScreen(child: Center(child: ProgressRing())),
    ),
    errorBuilder: (context, error) => _PopOnEscape(
      child: PopcornFluentSplashScreen(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
    builder: (context, bundle) => _PopOnEscape(
      child: PopcornFluentSplashScreen(
        child: FluentMediaDetailsView(
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
  );
}

class _WindowsHomeView extends StatelessWidget {
  const _WindowsHomeView({required this.services, this.initialQuery, this.initialMediaType});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  @override
  Widget build(BuildContext context) {
    return PopcornFluentSplashScreen(
      child: FluentMediaSearchView(
        controller: services.searchController,
        favoritesController: services.favoritesController,
        authController: services.authController,
        initialQuery: initialQuery,
        initialMediaType: initialMediaType,
        onMediaSelected: (media) => Navigator.of(context).pushNamed(AppRoutes.details(services.searchController.mediaType, media.id), arguments: media),
        onMediaPlay: (media) => Navigator.of(context).pushNamed(AppRoutes.watch(services.searchController.mediaType, media.id), arguments: media),
        onOpenFavorites: () => Navigator.of(context).pushNamed(AppRoutes.favorites),
        onOpenContinueWatching: () => Navigator.of(context).pushNamed(AppRoutes.history),
      ),
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
