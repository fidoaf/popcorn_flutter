import 'dart:io';
import 'dart:ui';

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

import 'src/app/view/material/splash_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  // Fire TV is landscape-only and controlled with a remote, so lock the
  // orientation and hide the system bars for a full-screen 10-foot experience.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await dotenv.load(fileName: 'assets/config/app.env');
  await initializeDateFormatting();
  await AuthController.ensureInitialized();
  runApp(const _PopcornTvApp());
}

class _PopcornTvApp extends StatefulWidget {
  const _PopcornTvApp();

  @override
  State<_PopcornTvApp> createState() => _PopcornTvAppState();

  static ThemeData _tvTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: brightness);
    // Keep the deep-orange accents but replace the seed-tinted (brownish) dark
    // surfaces with a neutral, cinematic dark palette so the 10-foot UI reads as
    // near-black rather than brown. Light variant is untouched (TV forces dark).
    final tuned = brightness == Brightness.dark
        ? scheme.copyWith(
            surface: const Color(0xFF1A1A2E),
            surfaceContainerLowest: const Color(0xFF141421),
            surfaceContainerLow: const Color(0xFF1E1E33),
            surfaceContainer: const Color(0xFF23233B),
            surfaceContainerHigh: const Color(0xFF2A2A45),
            surfaceContainerHighest: const Color(0xFF30304F),
          )
        : scheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: tuned,
      scaffoldBackgroundColor: tuned.surface,
      // Strong focus color so the selected element is visible from across the
      // room. Text is scaled up globally in [_TvNavigationScope].
      focusColor: Colors.deepOrangeAccent.withValues(alpha: 0.6),
    );
  }
}

class _PopcornTvAppState extends State<_PopcornTvApp> {
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
    return MaterialApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.dark,
      theme: _PopcornTvApp._tvTheme(Brightness.light),
      darkTheme: _PopcornTvApp._tvTheme(Brightness.dark),
      builder: (context, child) => _TvNavigationScope(
        child: SystemBarsBackground(
          child: AuthGate(
            controller: _services.authController,
            currentRoute: _routeObserver.routeName,
            isPublicRoute: AppRoutes.isPublic,
            loginBuilder: (context) => MaterialLoginView(
              controller: _services.authController,
              onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
              onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
            ),
            child: child!,
          ),
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

  Route<dynamic> _buildRoute(RouteSettings settings, AppRouteRequest request) =>
      MaterialPageRoute<void>(settings: settings, builder: (context) => _pageFor(context, request, settings.arguments));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case LandingRoute():
        return _landingPage(context);
      case HomeRoute():
      case UnknownRoute():
        return _TvHomeView(services: _services);
      case SearchRoute(:final query, :final type):
        return _TvHomeView(services: _services, initialQuery: query, initialMediaType: type);
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
        return video == null ? _TvHomeView(services: _services) : _trailerPage(video);
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
      onEnter: () => _navigatorKey.currentState?.pushNamed(AppRoutes.home),
      onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
      onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
    ),
  );

  Widget _playerPage(BuildContext context, Widget player) => _PopOnBack(
    child: PopcornMaterialSplashScreen(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ),
        body: SafeArea(child: player),
      ),
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
    loadingBuilder: (context) => _playerPage(context, const Center(child: CircularProgressIndicator())),
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
            autofocusPlay: true,
          ),
        ),
      ),
    ),
  );
}

/// Forces directional (D-pad) focus traversal for the whole app so the Fire TV
/// remote can move between focusable widgets.
class _TvNavigationScope extends StatelessWidget {
  const _TvNavigationScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      // Force directional (D-pad) focus traversal and scale text up for the
      // 10-foot viewing distance, without touching individual text styles.
      data: media.copyWith(
        navigationMode: NavigationMode.directional,
        textScaler: TextScaler.linear(media.textScaler.scale(1.8) / media.textScaler.scale(1.0)),
      ),
      child: child,
    );
  }
}

class _TvHomeView extends StatelessWidget {
  const _TvHomeView({required this.services, this.initialQuery, this.initialMediaType});

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
          enableDpadFocus: true,
        ),
      ),
    );
  }
}

/// Pops the current route when the Fire TV remote's Back button is pressed.
///
/// The player is a native WebView whose controls are HTML rendered by the
/// embedded player, so the D-pad must reach the WebView, not this widget.
/// [canRequestFocus] is `false` so this node never steals focus from the
/// WebView; it still receives Back/Escape key events because they bubble up
/// from the focused descendant.
class _PopOnBack extends StatelessWidget {
  const _PopOnBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.goBack || event.logicalKey == LogicalKeyboardKey.escape)) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
