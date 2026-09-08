import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Outcome of scraping a single streaming provider for a playable HLS stream.
///
/// Mirrors the per-provider shape returned by the original Node/Express
/// `/extract` endpoint (`{ hls_url, subtitles, error }`).
class HlsExtractionResult {
  const HlsExtractionResult({this.hlsUrl, this.subtitles = const <String>[], this.error});

  /// The captured `.m3u8` URL, or `null` when none was observed.
  final String? hlsUrl;

  /// Any `.vtt`/`.srt` URLs seen while the page loaded.
  final List<String> subtitles;

  /// A human-readable failure reason, or `null` on success.
  final String? error;

  bool get success => hlsUrl != null;
}

/// A Dart port of the Playwright-based `/extract` scraper, built on
/// `flutter_inappwebview` instead of a headless Chromium.
///
/// It loads a provider's embed page in an offscreen [HeadlessInAppWebView],
/// simulates the play click, and captures the first `.m3u8` request (plus any
/// subtitle requests) via [HeadlessInAppWebView.onLoadResource].
///
/// Platform support: request observation through `onLoadResource` is reliable
/// on Android and iOS. On desktop/web the headless WebView and resource hooks
/// are limited or unavailable, so extraction there should be treated as
/// best-effort/unsupported.
class HlsExtractorService {
  HlsExtractorService({
    List<String>? providers,
    this.perProviderTimeout = const Duration(seconds: 20),
    this.playClickDelay = const Duration(seconds: 1),
    this.maxConcurrent = 2,
    this.cacheTtl = const Duration(minutes: 15),
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
  }) : providers = providers ?? defaultProviders;

  /// Provider base URLs, defaulting to [defaultProviders] (the server's list).
  final List<String> providers;

  /// How long to wait for a `.m3u8` request per provider before giving up.
  final Duration perProviderTimeout;

  /// Delay after `onLoadStop` before issuing the play click, giving the embed's
  /// own scripts time to attach the player element.
  final Duration playClickDelay;

  /// Maximum number of providers scraped concurrently (mirrors `pLimit(2)`).
  final int maxConcurrent;

  /// How long a successful multi-provider result is served from cache.
  final Duration cacheTtl;

  /// User-agent presented to the embed pages.
  final String userAgent;

  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  /// The default provider hosts, matching the original server's `PROVIDERS`.
  static const List<String> defaultProviders = <String>[
    'https://vidsrc.ir',
    // 'https://vidsrc2.ru',
    // 'https://vidsrcme.ru',
    // 'https://vidsrcme.su',
    // 'https://vidsrc-me.ru',
    // 'https://vidsrc.me',
    // 'https://vidsrc.io',
    // 'https://vidsrc.tw',
  ];

  /// Scrapes every provider for [tmdbId] and returns one result per provider,
  /// keyed by provider base URL. Mirrors the `/extract` endpoint.
  ///
  /// [type] is `movie` or `tv`; [season]/[episode] are required for `tv`.
  /// Successful lookups are cached for [cacheTtl].
  Future<Map<String, HlsExtractionResult>> extractAll(String tmdbId, {String type = 'movie', int? season, int? episode}) async {
    if (type == 'tv' && (season == null || episode == null)) {
      throw ArgumentError('season and episode are required for TV shows');
    }

    final String cacheKey = '$type|$tmdbId|$season|$episode';
    final _CacheEntry? cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.storedAt) < cacheTtl) {
      return cached.results;
    }

    final Map<String, String> urls = <String, String>{for (final String domain in providers) domain: _buildEmbedUrl(domain, tmdbId, type, season, episode)};

    final Map<String, HlsExtractionResult> results = await _mapWithLimit(urls.entries, maxConcurrent, (MapEntry<String, String> entry) async {
      try {
        final HlsExtractionResult result = await extractOne(Uri.parse(entry.value));
        return MapEntry<String, HlsExtractionResult>(entry.key, result);
      } on Object catch (error) {
        return MapEntry<String, HlsExtractionResult>(entry.key, HlsExtractionResult(error: error.toString()));
      }
    });

    if (results.values.any((HlsExtractionResult r) => r.success)) {
      _cache[cacheKey] = _CacheEntry(storedAt: DateTime.now(), results: results);
    }
    return results;
  }

  /// Scrapes a single embed [url] for its `.m3u8` stream and subtitle requests.
  ///
  /// This is the direct equivalent of the server's `scrapeProvider`.
  Future<HlsExtractionResult> extractOne(Uri url) async {
    final Completer<String> hlsCompleter = Completer<String>();
    final List<String> subtitles = <String>[];
    HeadlessInAppWebView? webView;

    void onResource(String resourceUrl) {
      if (!hlsCompleter.isCompleted && resourceUrl.contains('.m3u8')) {
        hlsCompleter.complete(resourceUrl);
      }
      if (_isSubtitle(resourceUrl) && !subtitles.contains(resourceUrl)) {
        subtitles.add(resourceUrl);
      }
    }

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri.uri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent: userAgent,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          // Required for [onLoadResource] to fire for the page's requests.
          useOnLoadResource: true,
          supportMultipleWindows: false,
          javaScriptCanOpenWindowsAutomatically: false,
        ),
        onLoadResource: (_, LoadedResource resource) {
          final String? resourceUrl = resource.url?.toString();
          if (resourceUrl != null) onResource(resourceUrl);
        },
        onLoadStop: (InAppWebViewController controller, _) async {
          // Give the embed's scripts a moment, then click the play surface,
          // matching the server's `#the_frame` click.
          await Future<void>.delayed(playClickDelay);
          await controller.evaluateJavascript(source: "document.querySelector('#the_frame')?.click(); document.querySelector('video')?.play();");
        },
      );

      await webView.run();

      final String hlsUrl = await hlsCompleter.future.timeout(perProviderTimeout);
      return HlsExtractionResult(hlsUrl: hlsUrl, subtitles: subtitles);
    } on TimeoutException {
      return HlsExtractionResult(subtitles: subtitles, error: 'HLS URL not found');
    } on Object catch (error) {
      return HlsExtractionResult(subtitles: subtitles, error: error.toString());
    } finally {
      await webView?.dispose();
    }
  }

  /// Clears the in-memory extraction cache.
  void clearCache() => _cache.clear();

  String _buildEmbedUrl(String domain, String tmdbId, String type, int? season, int? episode) =>
      type == 'tv' ? '$domain/embed/tv?tmdb=$tmdbId&season=$season&episode=$episode' : '$domain/embed/movie/$tmdbId';

  static bool _isSubtitle(String url) => RegExp(r'\.(vtt|srt)(\?.*)?$').hasMatch(url) || url.contains('.vtt') || url.contains('.srt');

  /// Runs [task] over [items] with at most [limit] in flight at once, returning
  /// a map built from the yielded entries (order-independent).
  static Future<Map<K, V>> _mapWithLimit<T, K, V>(Iterable<T> items, int limit, Future<MapEntry<K, V>> Function(T) task) async {
    final List<T> queue = items.toList();
    final Map<K, V> results = <K, V>{};
    int next = 0;

    Future<void> worker() async {
      while (true) {
        final int index = next++;
        if (index >= queue.length) return;
        final MapEntry<K, V> entry = await task(queue[index]);
        results[entry.key] = entry.value;
      }
    }

    final int workers = limit < 1 ? 1 : limit;
    await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));
    return results;
  }
}

class _CacheEntry {
  const _CacheEntry({required this.storedAt, required this.results});

  final DateTime storedAt;
  final Map<String, HlsExtractionResult> results;
}
