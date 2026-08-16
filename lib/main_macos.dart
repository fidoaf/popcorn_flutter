import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/routing/routing.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/macos/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/auth/auth.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/details/view/macos/macos_media_details_view.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
import 'package:popcorn_flutter/src/history/history.dart';
import 'package:popcorn_flutter/src/legal/legal.dart';
import 'package:popcorn_flutter/src/locale/domain/app_language.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isMacOS) {
    runApp(const UnsupportedPlatformView());
    return;
  }
  await dotenv.load(fileName: 'assets/config/app.env');
  await AuthController.ensureInitialized();
  runApp(const _PopcornMacosApp());
}

class _PopcornMacosApp extends StatefulWidget {
  const _PopcornMacosApp();

  @override
  State<_PopcornMacosApp> createState() => _PopcornMacosAppState();
}

class _PopcornMacosAppState extends State<_PopcornMacosApp> {
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
    return MacosApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      builder: (context, child) => AuthGate(
        controller: _services.authController,
        currentRoute: _routeObserver.routeName,
        isPublicRoute: AppRoutes.isPublic,
        loginBuilder: (context) => MacosLoginView(
          controller: _services.authController,
          onOpenPrivacy: () => _navigatorKey.currentState?.pushNamed(AppRoutes.privacy),
          onOpenTerms: () => _navigatorKey.currentState?.pushNamed(AppRoutes.terms),
        ),
        child: child!,
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
      CupertinoPageRoute<void>(settings: settings, builder: (context) => _pageFor(context, request, settings.arguments));

  Widget _pageFor(BuildContext context, AppRouteRequest request, Object? arguments) {
    switch (request) {
      case HomeRoute():
      case UnknownRoute():
        return _MacosHomeView(services: _services);
      case SearchRoute(:final query, :final type):
        return _MacosHomeView(services: _services, initialQuery: query, initialMediaType: type);
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
        return video == null ? _MacosHomeView(services: _services) : _trailerPage(video);
      case PrivacyRoute():
        return _legalPage(context, LegalTranslations.privacyPolicy);
      case TermsRoute():
        return _legalPage(context, LegalTranslations.termsOfService);
    }
  }

  Widget _legalPage(BuildContext context, LegalDocument document) => PopcornMacosSplashScreen(
    child: MacosScaffold(
      toolBar: ToolBar(
        title: Text(document.title.trOf(context)),
        leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      children: [ContentArea(builder: (context, _) => LegalDocumentView(document: document))],
    ),
  );

  Widget _playerPage(BuildContext context, String title, Widget player) => PopcornMacosSplashScreen(
    child: MacosScaffold(
      toolBar: ToolBar(
        title: Text(title),
        leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      children: [ContentArea(builder: (context, _) => player)],
    ),
  );

  Widget _favoritesPage(BuildContext context) => PopcornMacosSplashScreen(
    child: MacosScaffold(
      toolBar: ToolBar(
        title: Text(FavoritesTranslations.pageTitle.trOf(context)),
        leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      children: [
        ContentArea(
          builder: (context, _) => MacosFavoritesView(
            controller: _services.favoritesController,
            onMediaSelected: (favorite) => Navigator.of(context).pushNamed(AppRoutes.details(favorite.type, favorite.item.id), arguments: favorite.item),
          ),
        ),
      ],
    ),
  );

  Widget _historyPage(BuildContext context) => PopcornMacosSplashScreen(
    child: MacosScaffold(
      toolBar: ToolBar(
        title: Text(WatchHistoryTranslations.pageTitle.trOf(context)),
        leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      children: [
        ContentArea(
          builder: (context, _) => MacosContinueWatchingView(
            controller: _services.historyController,
            onMediaSelected: (entry) => Navigator.of(context).pushNamed(AppRoutes.details(entry.type, entry.item.id), arguments: entry.item),
            onMediaPlay: (entry) => Navigator.of(context).pushNamed(
              AppRoutes.watch(entry.type, entry.item.id, season: entry.season, episode: entry.episode),
              arguments: entry.item,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _watchPage(MediaType type, int id, int? season, int? episode, MediaItem? item) => MediaPlaybackScaffold(
    id: id,
    type: type,
    season: season,
    episode: episode,
    item: item,
    services: _services,
    loadingBuilder: (context) => _playerPage(context, '', const Center(child: ProgressCircle())),
    builder: (context, source, resolved) => _playerPage(context, resolved.title, VideoPlayerFactory.create(source: source)),
  );

  Widget _trailerPage(MediaVideo video) => Builder(
    builder: (context) => _playerPage(
      context,
      video.name,
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
    loadingBuilder: (context) => PopcornMacosSplashScreen(
      child: MacosScaffold(
        toolBar: ToolBar(leading: MacosBackButton(onPressed: () => Navigator.of(context).pop())),
        children: const [ContentArea(builder: _macosLoadingBuilder)],
      ),
    ),
    errorBuilder: (context, error) => PopcornMacosSplashScreen(
      child: MacosScaffold(
        toolBar: ToolBar(leading: MacosBackButton(onPressed: () => Navigator.of(context).pop())),
        children: [
          ContentArea(
            builder: (context, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$error', textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    ),
    builder: (context, bundle) => PopcornMacosSplashScreen(
      child: MacosScaffold(
        toolBar: ToolBar(
          title: Text(bundle.item.title),
          leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        children: [
          ContentArea(
            builder: (context, _) => MacosMediaDetailsView(
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
        ],
      ),
    ),
  );

  static Widget _macosLoadingBuilder(BuildContext context, ScrollController _) => const Center(child: ProgressCircle());
}

class _MacosHomeView extends StatelessWidget {
  const _MacosHomeView({required this.services, this.initialQuery, this.initialMediaType});

  final AppServices services;
  final String? initialQuery;
  final MediaType? initialMediaType;

  @override
  Widget build(BuildContext context) {
    return PopcornMacosSplashScreen(
      child: MacosWindow(
        child: MacosScaffold(
          toolBar: ToolBar(
            title: Text(SearchTranslations.pageTitle.trOf(context)),
            actions: [
              ToolBarIconButton(
                label: WatchHistoryTranslations.pageTitle.trOf(context),
                icon: const MacosIcon(CupertinoIcons.play_rectangle),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
                showLabel: false,
              ),
              ToolBarIconButton(
                label: FavoritesTranslations.pageTitle.trOf(context),
                icon: const MacosIcon(CupertinoIcons.heart),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.favorites),
                showLabel: false,
              ),
            ],
          ),
          children: [
            ContentArea(
              builder: (context, _) => MacosMediaSearchView(
                controller: services.searchController,
                favoritesController: services.favoritesController,
                initialQuery: initialQuery,
                initialMediaType: initialMediaType,
                onMediaSelected: (media) => Navigator.of(context).pushNamed(AppRoutes.details(services.searchController.mediaType, media.id), arguments: media),
                onMediaPlay: (media) => Navigator.of(context).pushNamed(AppRoutes.watch(services.searchController.mediaType, media.id), arguments: media),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
