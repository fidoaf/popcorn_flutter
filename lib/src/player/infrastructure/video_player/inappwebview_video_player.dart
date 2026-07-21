import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';

final class InappwebviewVideoPlayer extends VideoPlayer {
  const InappwebviewVideoPlayer({super.key, required super.source, required this.fullscreenController});

  final FullscreenController fullscreenController;

  /// Translates the domain [MediaSource] into a WebView request, carrying its
  /// method, headers and body.
  URLRequest get _request =>
      URLRequest(url: WebUri.uri(source.url), method: source.method.value, headers: source.headers.isEmpty ? null : source.headers, body: source.body);

  @override
  Widget build(BuildContext context) {
    final hasCookies = source.cookies.isNotEmpty;
    return InAppWebView(
      // Cookies must be installed before the page loads, so when the source
      // carries any, defer the initial navigation to [onWebViewCreated].
      initialUrlRequest: hasCookies ? null : _request,
      onWebViewCreated: hasCookies ? _loadWithCookies : null,
      initialSettings: InAppWebViewSettings(
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
        if (request == null || navigationAction.isForMainFrame != true || request.host == source.url.host) {
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
