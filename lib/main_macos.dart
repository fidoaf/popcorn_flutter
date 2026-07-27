import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/macos/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
import 'package:popcorn_flutter/src/details/view/macos/macos_media_details_view.dart';
import 'package:popcorn_flutter/src/favorites/favorites.dart';
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
  await dotenv.load();
  runApp(const _PopcornMacosApp());
}

class _PopcornMacosApp extends StatelessWidget {
  const _PopcornMacosApp();

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.system,
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      home: const _MacosHomeView(),
    );
  }
}

class _MacosHomeView extends StatefulWidget {
  const _MacosHomeView();

  @override
  State<_MacosHomeView> createState() => _MacosHomeViewState();
}

class _MacosHomeViewState extends State<_MacosHomeView> {
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
      CupertinoPageRoute<void>(
        builder: (_) => PopcornMacosSplashScreen(
          child: MacosScaffold(
            toolBar: ToolBar(
              title: Text(media.title),
              leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
            ),
            children: [ContentArea(builder: (context, _) => VideoPlayerFactory.create(source: source))],
          ),
        ),
      ),
    );
  }

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!, data: video.embedHtml);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PopcornMacosSplashScreen(
          child: MacosScaffold(
            toolBar: ToolBar(
              title: Text(video.name),
              leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
            ),
            children: [ContentArea(builder: (context, _) => VideoPlayerFactory.create(source: source))],
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
      CupertinoPageRoute<void>(
        builder: (_) => PopcornMacosSplashScreen(
          child: MacosScaffold(
            toolBar: ToolBar(
              title: Text(media.title),
              leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
            ),
            children: [
              ContentArea(
                builder: (context, _) => MacosMediaDetailsView(
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
            ],
          ),
        ),
      ),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PopcornMacosSplashScreen(
          child: MacosScaffold(
            toolBar: ToolBar(
              title: Text(FavoritesTranslations.pageTitle.trOf(context)),
              leading: MacosBackButton(onPressed: () => Navigator.of(context).pop()),
            ),
            children: [
              ContentArea(
                builder: (context, _) => MacosFavoritesView(
                  controller: _favoritesController,
                  onMediaSelected: (favorite) => _openDetailsFor(favorite.item, favorite.type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornMacosSplashScreen(
      child: MacosWindow(
        child: MacosScaffold(
          toolBar: ToolBar(
            title: Text(SearchTranslations.pageTitle.trOf(context)),
            actions: [
              ToolBarIconButton(
                label: FavoritesTranslations.pageTitle.trOf(context),
                icon: const MacosIcon(CupertinoIcons.heart),
                onPressed: _openFavorites,
                showLabel: false,
              ),
            ],
          ),
          children: [
            ContentArea(
              builder: (context, _) => MacosMediaSearchView(
                controller: _searchController,
                favoritesController: _favoritesController,
                onMediaSelected: _openDetails,
                onMediaPlay: _openMedia,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
