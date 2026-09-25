import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';

final class InappwebviewVideoPlayer extends VideoPlayer {
  const InappwebviewVideoPlayer({super.key, required super.source, required this.fullscreenController, super.onUrlChanged});

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

  /// Whether inline embed HTML must be delivered through request interception
  /// rather than `InAppWebViewInitialData`.
  ///
  /// On Windows the WebView2 engine loads inline data via `NavigateToString`,
  /// which discards the supplied base URL and assigns the document a `null`
  /// origin. YouTube's embedded player then rejects playback ("error 153").
  /// Serving the very same HTML as the response to a real navigation to
  /// [_embedBaseUrl] gives the document a genuine origin, matching the behaviour
  /// other platforms get for free from `baseUrl`.
  bool get _serveEmbedViaInterception => source.data != null && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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
    // Browsers forbid setting `Referer` manually and reject any custom header
    // on the iframe load, so only add it off the web.
    if (!kIsWeb && isHttp && !headers.keys.any((key) => key.toLowerCase() == 'referer')) {
      headers['Referer'] = source.url.origin;
    }
    return URLRequest(url: WebUri.uri(source.url), method: source.method.value, headers: headers, body: source.body);
  }

  /// Resolves the web `<iframe>` sandbox from the source's `sandbox` flag:
  /// `false` grants every permission (effectively unsandboxed), `true` keeps a
  /// protective sandbox that still lets the embedded player run, and `null`
  /// uses the platform default.
  Set<Sandbox>? get _iframeSandbox => switch (source.sandbox) {
    true => {
      Sandbox.ALLOW_SCRIPTS,
      Sandbox.ALLOW_SAME_ORIGIN,
      Sandbox.ALLOW_FORMS,
      Sandbox.ALLOW_POPUPS,
      Sandbox.ALLOW_POPUPS_TO_ESCAPE_SANDBOX,
      Sandbox.ALLOW_PRESENTATION,
    },
    false => Sandbox.values.toSet(),
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    // Some providers ship a self-contained HTML player (see [MediaSource.data])
    // that must be rendered under a realistic origin so the embedded player's
    // anti-abuse checks pass.
    final hasData = source.data != null;
    final hasCookies = source.cookies.isNotEmpty;
    final homeHost = _baseUrl.host;
    // On Windows the inline document is delivered by intercepting a real
    // navigation to the base URL (see [_serveEmbedViaInterception]); elsewhere
    // it is handed to the WebView directly as initial data.
    final serveViaInterception = _serveEmbedViaInterception;
    final useInitialData = hasData && !serveViaInterception;
    // Windows (WebView2) does not fire [onLoadResource], so requests are
    // monitored through [shouldInterceptRequest] there instead (its native
    // filter sees every request, including those made from within iframes).
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final interceptRequests = serveViaInterception || isWindows;
    return InAppWebView(
      // Cookies must be installed before the page loads, so when the source
      // carries any, defer the initial navigation to [onWebViewCreated]. When
      // serving inline data through interception, navigate to the base URL so
      // the intercepted response establishes a real document origin.
      initialUrlRequest: hasCookies || useInitialData
          ? null
          : serveViaInterception
          ? URLRequest(url: _baseUrl)
          : _request,
      initialData: useInitialData ? InAppWebViewInitialData(data: source.data!, baseUrl: _baseUrl) : null,
      onWebViewCreated: hasCookies ? _loadWithCookies : null,
      // On Windows, log every intercepted request and serve the inline embed
      // HTML for the base-URL navigation; elsewhere interception is unused.
      shouldInterceptRequest: interceptRequests ? _interceptRequest : null,
      initialSettings: InAppWebViewSettings(
        // Present a mainstream browser identity for inline embed documents to
        // avoid YouTube's WebView bot detection.
        userAgent: hasData ? _embedUserAgent : null,
        // Sandbox the web `<iframe>` per the source's `sandbox` flag.
        iframeSandbox: _iframeSandbox,
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
        // Required so [shouldInterceptRequest] is invoked to monitor requests
        // and serve the inline embed document under a real origin on Windows.
        useShouldInterceptRequest: interceptRequests,
        // Required so [onLoadResource] reports every resource the WebView loads
        // (including those requested from within iframes).
        useOnLoadResource: true,
        // Keep everything inside this WebView: never spawn a separate window
        // for `window.open`/`target="_blank"` links (see [onCreateWindow]).
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
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
      // Veto any request to open a new window (pop-ups, `target="_blank"`,
      // `window.open`), so nothing escapes the player.
      onCreateWindow: (controller, createWindowAction) async => false,
      // Log every URL the WebView loads, including resources requested from
      // within iframes (the embedded player, ad frames, media streams, etc.).
      onLoadResource: (controller, resource) {
        final url = resource.url;
        if (url != null) debugPrint('[VideoPlayer] loaded ${resource.initiatorType ?? 'resource'}: $url');
      },
      onEnterFullscreen: (_) => fullscreenController.setFullscreen(true),
      onExitFullscreen: (_) => fullscreenController.setFullscreen(false),
      // Report client-side navigations (e.g. the embedded player advancing to
      // the next episode) so callers can update the watch history.
      onUpdateVisitedHistory: onUrlChanged == null
          ? null
          : (controller, url, isReload) {
              if (url != null) onUrlChanged!(url);
            },
    );
  }

  /// Logs every intercepted request and, when serving the inline embed
  /// document (Windows, see [_serveEmbedViaInterception]), answers the base-URL
  /// navigation with it. All other requests return `null` to load normally.
  ///
  /// Interception is the only way to observe iframe resource loads on Windows,
  /// where [onLoadResource] does not fire.
  Future<WebResourceResponse?> _interceptRequest(InAppWebViewController controller, WebResourceRequest request) async {
    debugPrint('[VideoPlayer] loaded resource: ${request.url}');
    if (!_serveEmbedViaInterception) return null;
    final isBaseDocument = request.url.host == _baseUrl.host && (request.url.path.isEmpty || request.url.path == '/');
    if (!isBaseDocument) return null;
    return WebResourceResponse(contentType: 'text/html', contentEncoding: 'utf-8', data: Uint8List.fromList(utf8.encode(source.data!)));
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
