import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/domain/video_player.dart';

final class InappwebviewVideoPlayer extends VideoPlayer {
  const InappwebviewVideoPlayer({super.key, required super.source, required this.fullscreenController});

  final FullscreenController fullscreenController;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(source)),
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
        if (request == null || navigationAction.isForMainFrame != true || request.host == source.host) {
          return NavigationActionPolicy.ALLOW;
        }
        return NavigationActionPolicy.CANCEL;
      },
      onEnterFullscreen: (_) => fullscreenController.setFullscreen(true),
      onExitFullscreen: (_) => fullscreenController.setFullscreen(false),
    );
  }
}
