import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';

final class InappwebviewVideoPlayer extends VideoPlayer {
  const InappwebviewVideoPlayer({super.key, required super.source, required this.fullscreenController});

  final FullscreenController fullscreenController;

  /// A mainstream browser identity. The default WebView user agent is flagged
  /// by YouTube's bot detection (surfaced as embed "error 152-4"), so inline
  /// embed documents are served under a common desktop-class agent instead.
  static const _embedUserAgent = 'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Origin applied to inline embed documents (see [MediaSource.data]).
  /// YouTube's anti-abuse checks reject `youtube.com` itself as the embedding
  /// origin, so a neutral site-like base URL is presented instead.
  static const _embedBaseUrl = 'https://popcorn.flutter.app';

  /// The document origin the WebView is pinned to: the embed base URL for
  /// inline documents, otherwise the source's own host.
  WebUri get _baseUrl => source.data != null ? WebUri(_embedBaseUrl) : WebUri.uri(source.url);

  /// Translates the domain [MediaSource] into a WebView request, carrying its
  /// method, headers and body.
  ///
  /// Embedded players (e.g. YouTube) reject playback with a missing HTTP
  /// referrer (YouTube surfaces this as "error 153"), so when the source does
  /// not already provide a `Referer` header we default it to the target's own
  /// origin, which satisfies the check without leaking any other context.
  URLRequest get _request {
    final headers = <String, String>{...source.headers};
    final isHttp = source.url.isScheme('http') || source.url.isScheme('https');
    if (isHttp && !headers.keys.any((key) => key.toLowerCase() == 'referer')) {
      headers['Referer'] = source.url.origin;
    }
    return URLRequest(url: WebUri.uri(source.url), method: source.method.value, headers: headers, body: source.body);
  }

  @override
  Widget build(BuildContext context) {
    // Some providers ship a self-contained HTML player (see [MediaSource.data])
    // that must be rendered under a realistic origin so the embedded player's
    // anti-abuse checks pass.
    final hasData = source.data != null;
    final hasCookies = source.cookies.isNotEmpty;
    final homeHost = _baseUrl.host;
    return InAppWebView(
      // Cookies must be installed before the page loads, so when the source
      // carries any, defer the initial navigation to [onWebViewCreated].
      initialUrlRequest: hasData || hasCookies ? null : _request,
      initialData: hasData ? InAppWebViewInitialData(data: source.data!, baseUrl: _baseUrl) : null,
      onWebViewCreated: hasCookies ? _loadWithCookies : null,
      initialSettings: InAppWebViewSettings(
        // Present a mainstream browser identity for inline embed documents to
        // avoid YouTube's WebView bot detection.
        userAgent: hasData ? _embedUserAgent : null,
        // Allow the video/player to request fullscreen. On web the WebView is
        // hosted inside an <iframe>, which must be granted these permissions
        // for the HTML Fullscreen API (and thus the callbacks below) to work.
        iframeAllow: 'fullscreen; autoplay; encrypted-media; picture-in-picture',
        iframeAllowFullscreen: true,
        // Let the embedded player start/handle media without a prior gesture.
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        // Required so [shouldOverrideUrlLoading] is invoked and can veto
        // top-level navigations away from the provided URL.
        useShouldOverrideUrlLoading: true,
      ),
      // Keep the WebView pinned to the provided URL: allow sub-frame content
      // (e.g. the embedded player iframe) and same-host navigations, but cancel
      // any top-level navigation to a different host (external links/redirects).
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final request = navigationAction.request.url;
        if (request == null || navigationAction.isForMainFrame != true || request.host == homeHost) {
          return NavigationActionPolicy.ALLOW;
        }
        return NavigationActionPolicy.CANCEL;
      },
      onEnterFullscreen: (_) => fullscreenController.setFullscreen(true),
      onExitFullscreen: (_) => fullscreenController.setFullscreen(false),
    );
  }

  /// Installs the source's cookies and then loads the request, used when the
  /// [MediaSource] requires cookies to be present before the first navigation.
  Future<void> _loadWithCookies(InAppWebViewController controller) async {
    final cookieManager = CookieManager.instance();
    final url = WebUri.uri(source.url);
    for (final cookie in source.cookies) {
      await cookieManager.setCookie(url: url, name: cookie.name, value: cookie.value, domain: cookie.domain, path: cookie.path);
    }
    await controller.loadUrl(urlRequest: _request);
  }
}
