import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';
import 'package:popcorn_flutter/shared/core/model/web_renderer.dart';

class InAppWebRenderer implements IWebRenderer {
  static final InAppWebRenderer _singleton = InAppWebRenderer._internal();

  factory InAppWebRenderer() {
    return _singleton;
  }

  InAppWebRenderer._internal();

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
  Future<bool> check(String url) async {
    // final response = await get(Uri.parse(url));
    // return response.statusCode == HttpStatus.accepted;
    return true;
  }

  @override
  Future<bool> launch(String url) async {
    // await FullScreenWindow.setFullScreen(true);
    Navigator.push(
      NavigationService.navigatorKey.currentContext!,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            body: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _closePlayer();
                }
              },
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri('https://vidsrc.xyz/embed/tv?imdb=tt11280740&season=1&episode=1&color=e600e6')),
                    keepAlive: InAppWebViewKeepAlive(),
                    initialSettings: InAppWebViewSettings(),
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage.message);
                    },
                    onCreateWindow: (controller, createWindowAction) async {
                      return false;
                    },
                    onEnterFullscreen: (controller) {
                      print('object');
                    },
                    onPermissionRequest: (controller, permissionRequest) async {
                      print('object');
                      return null;
                    },
                    // preventGestureDelay: ,
                    shouldOverrideUrlLoading: (
                      controller,
                      navigationAction,
                    ) async {
                      final uri = navigationAction.request.url;
                      if ([
                        'vidsrc.xyz',
                        'edgedeliverynetwork.com',
                      ].contains(uri?.host)) {
                        print(navigationAction);
                        return NavigationActionPolicy.ALLOW;
                      } else {
                        print('URL cancelled ${uri.toString()}');
                        return NavigationActionPolicy.CANCEL;
                      }
                    },
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
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
