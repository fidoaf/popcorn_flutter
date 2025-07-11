import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';
import 'package:popcorn_flutter/shared/core/model/web_renderer.dart';

class InAppWebRenderer implements IWebRenderer {
  static final InAppWebRenderer _singleton = InAppWebRenderer._internal();

  factory InAppWebRenderer() {
    return _singleton;
  }

  InAppWebRenderer._internal();

final GlobalKey _webviewKey = GlobalKey();
  final FocusNode _mainFocus = FocusNode();

  void _closePlayer() async {
    await FullScreenWindow.setFullScreen(false);
    Navigator.pop(NavigationService.navigatorKey.currentContext!);
  }

  void _goToPreviousEpisode() {
    Navigator.pop(NavigationService.navigatorKey.currentContext!);
  }

  void _goToNextEpisode() {
    Navigator.pop(NavigationService.navigatorKey.currentContext!);
  }

  @override
  Future<bool> check(WebContentRenderSettings settings) async {
    // final response = await get(Uri.parse(url));
    // return response.statusCode == HttpStatus.accepted;
    return true;
  }

  @override
  Future<bool> launch(WebContentRenderSettings settings) async {
    final url = settings.url;

    await FullScreenWindow.setFullScreen(true);

    // TODO:
    // _mainFocus.addListener(() {
    //   if(!_mainFocus.hasPrimaryFocus){
    //     _mainFocus.requestFocus();
    //   }
    // });
    Navigator.push(
      NavigationService.navigatorKey.currentContext!,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            body: KeyboardListener(
              autofocus: true,
              focusNode: _mainFocus,
              onKeyEvent: (event) {
                // TODO:
                // if (event is KeyDownEvent &&
                //     event.logicalKey == LogicalKeyboardKey.escape) {
                //   _closePlayer();
                // }
              },
              child: Stack(
                children: [
                  InAppWebView(
                    key: _webviewKey,
                    initialUrlRequest: URLRequest(
                      url: WebUri.uri(Uri.parse(url)),
                    ),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllowFullscreen: true,
                      isElementFullscreenEnabled: true,
                    ),
                    shouldOverrideUrlLoading: (
                      controller,
                      navigationAction,
                    ) async {
                      final uri = navigationAction.request.url;
                      if ([
                        'vidsrc.xyz',
                        'edgedeliverynetwork.com',
                        'cloudnestra.com',
                      ].contains(uri?.host)) {
                        print(navigationAction);
                        return NavigationActionPolicy.ALLOW;
                      } else {
                        print('URL cancelled ${uri.toString()}');
                        return NavigationActionPolicy.CANCEL;
                      }
                    },
                    // TODO:
                    // onEnterFullscreen: (controller) {
                    //   FullScreenWindow.setFullScreen(true);
                    // },
                    // onExitFullscreen: (controller) {
                    //   FullScreenWindow.setFullScreen(false);
                    // },
                  ),

                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton.filledTonal(
                      onPressed: _closePlayer,
                      icon: const Icon(Icons.close),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToPreviousEpisode,
                      icon: const Icon(Icons.arrow_circle_left),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: _goToNextEpisode,
                      icon: const Icon(Icons.arrow_circle_right),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return true;
  }
}
