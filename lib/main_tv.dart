import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/app/view/unsupported_platform_view.dart';
import 'package:popcorn_flutter/src/details/details.dart';
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
  await dotenv.load();
  runApp(const _PopcornTvApp());
}

class _PopcornTvApp extends StatelessWidget {
  const _PopcornTvApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppTranslations.appTitle.trOf(context),
      locale: PlatformDispatcher.instance.locale,
      supportedLocales: AppLanguage.values.map((lang) => lang.locale),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      themeMode: ThemeMode.dark,
      theme: _tvTheme(Brightness.light),
      darkTheme: _tvTheme(Brightness.dark),
      builder: (context, child) => _TvNavigationScope(child: child!),
      home: const _TvHomeView(),
    );
  }

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

class _TvHomeView extends StatefulWidget {
  const _TvHomeView();

  @override
  State<_TvHomeView> createState() => _TvHomeViewState();
}

class _TvHomeViewState extends State<_TvHomeView> {
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
      MaterialPageRoute<void>(
        builder: (_) => _PopOnBack(
          child: PopcornMaterialSplashScreen(
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ),
              body: SafeArea(child: VideoPlayerFactory.create(source: source)),
            ),
          ),
        ),
      ),
    );
  }

  void _playVideo(MediaVideo video) {
    final source = MediaSource(url: video.embedUrl!);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PopOnBack(
          child: PopcornMaterialSplashScreen(
            child: Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ),
              body: SafeArea(child: VideoPlayerFactory.create(source: source)),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) {
    final details = _repository.details(media.id, _searchController.mediaType);
    final videos = _repository.videos(media.id, _searchController.mediaType);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PopcornMaterialSplashScreen(
          child: Scaffold(
            appBar: AppBar(title: Text(media.title)),
            body: SafeArea(
              child: MaterialMediaDetailsView(item: media, details: details, videos: videos, onPlay: _openMedia, onVideoPlay: _playVideo, autofocusPlay: true),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopcornMaterialSplashScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(SearchTranslations.pageTitle.trOf(context))),
        body: MaterialMediaSearchView(controller: _searchController, onMediaSelected: _openDetails, onMediaPlay: _openMedia, enableDpadFocus: true),
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
