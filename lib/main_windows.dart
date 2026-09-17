import 'dart:io';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/startup_error_app.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/fluent/splash_screen.dart';
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
  try {
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
  } catch (error, stack) {
    runApp(StartupErrorApp(message: 'Unable to start the app. Please check your configuration.', details: '$error\n$stack'));
    // ignore: avoid_print
    print('Startup error: $error\n$stack');
  }
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

  Widget _bootstrapApp(Widget home) => FluentApp(
    onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
    locale: PlatformDispatcher.instance.locale,
    supportedLocales: AppLanguage.values.map((lang) => lang.locale),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    themeMode: ThemeMode.system,
    theme: FluentThemeData.light(),
    darkTheme: FluentThemeData.dark(),
    home: home,
  );

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) return _bootstrapApp(const MaintenancePage());
    if (_servicesOrNull == null || _router == null) return _bootstrapApp(const PopcornFluentSplashScreen());
    return FluentApp.router(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: FluentThemeData.light(),
      darkTheme: FluentThemeData.dark(),
      routerConfig: _router!,
      builder: (context, child) => AuthGate(
        controller: _services.authController,
        currentRoute: _location,
        isPublicRoute: AppRoutes.isPublic,
        loginBuilder: (context) => FluentLoginView(
          controller: _services.authController,
          onOpenPrivacy: () => _router!.push(AppRoutes.privacy),
          onOpenTerms: () => _router!.push(AppRoutes.terms),
        ),
        child: child!,
      ),
    );
  }

  Page<void> _buildPage(BuildContext context, GoRouterState state, AppRouteRequest request) =>
      _FluentPage(key: state.pageKey, child: _pageFor(context, request, state.extra));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _WindowsHomeView(services: _services, browse: true);
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
        return video == null ? _WindowsHomeView(services: _services, browse: true) : _trailerPage(video);
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
      onEnter: () => context.go(AppRoutes.home),
      onOpenPrivacy: () => context.push(AppRoutes.privacy),
      onOpenTerms: () => context.push(AppRoutes.terms),
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
        onMediaSelected: (favorite) => context.push(AppRoutes.details(favorite.type, favorite.item.id), extra: favorite.item),
      ),
    ),
  );

  Widget _historyPage(BuildContext context) => _PopOnEscape(
    child: PopcornFluentSplashScreen(
      child: FluentContinueWatchingView(
        controller: _services.historyController,
        onMediaSelected: (entry) => context.push(AppRoutes.details(entry.type, entry.item.id), extra: entry.item),
        onMediaPlay: (entry) => context.push(
          AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
          extra: entry.item,
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
  );
}

class _WindowsHomeView extends StatelessWidget {
  const _WindowsHomeView({required this.services, this.initialQuery, this.initialMediaType, this.browse = false});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  /// When `true`, shows the streaming-style browse home instead of the
  /// search-first view.
  final bool browse;

  @override
  Widget build(BuildContext context) {
    if (browse) {
      return PopcornFluentSplashScreen(
        child: BrowseHomeView(
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
        ),
      );
    }
    return PopcornFluentSplashScreen(
      child: FluentMediaSearchView(
        controller: services.searchController,
        favoritesController: services.favoritesController,
        authController: services.authController,
        profileController: services.profileController,
        initialQuery: initialQuery,
        initialMediaType: initialMediaType,
        onMediaSelected: (media) => context.push(AppRoutes.details(services.searchController.mediaType, media.id), extra: media),
        onMediaPlay: (media) => context.push(AppRoutes.watch(services.searchController.mediaType, media.id), extra: media),
        onOpenFavorites: () => context.push(AppRoutes.favorites),
        onOpenContinueWatching: () => context.push(AppRoutes.history),
      ),
    );
  }
}

/// go_router [Page] that builds a [FluentPageRoute] so navigation keeps the
/// native Fluent page transition.
class _FluentPage extends Page<void> {
  const _FluentPage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => FluentPageRoute<void>(settings: this, builder: (_) => child);
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
