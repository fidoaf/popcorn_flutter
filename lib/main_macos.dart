import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/cupertino/splash_screen.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
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
    return CupertinoApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemOrange,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF1A1A2E),
        barBackgroundColor: Color(0xE01A1A2E),
      ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMedia(MediaItem media) {
    final source = _mediaSourceProvider.resolve(media, _searchController.mediaType);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PopcornCupertinoSplashScreen(
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              backgroundColor: const Color(0x001A1A2E),
              border: null,
              leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.of(context).pop(), child: const Icon(CupertinoIcons.xmark)),
            ),
            child: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PopcornCupertinoSplashScreen(
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              backgroundColor: const Color(0x001A1A2E),
              border: null,
              leading: CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.of(context).pop(), child: const Icon(CupertinoIcons.xmark)),
            ),
            child: SafeArea(child: VideoPlayerFactory.create(source: source)),
          ),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) {
    final details = _repository.details(media.id, _searchController.mediaType);
    final videos = _repository.videos(media.id, _searchController.mediaType);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PopcornCupertinoSplashScreen(
          child: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text(media.title), previousPageTitle: SearchTranslations.pageTitle.trOf(context)),
            child: SafeArea(
              child: CupertinoMediaDetailsView(item: media, details: details, videos: videos, onPlay: _openMedia, onVideoPlay: _playVideo),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornCupertinoSplashScreen(
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(SearchTranslations.pageTitle.trOf(context))),
        child: SafeArea(
          child: CupertinoMediaSearchView(controller: _searchController, onMediaSelected: _openDetails, onMediaPlay: _openMedia),
        ),
      ),
    );
  }
}
