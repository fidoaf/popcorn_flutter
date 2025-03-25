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

  void back() async {
    await FullScreenWindow.setFullScreen(false);
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
    await FullScreenWindow.setFullScreen(true);
    Navigator.push(
      NavigationService.navigatorKey.currentContext!,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            body: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                  back();
                }
              },
              child: Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(url)),
                    // preventGestureDelay: ,
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final uri = navigationAction.request.url;
                      if (['vidsrc.xyz', 'edgedeliverynetwork.com'].contains(uri?.host)) {
                        return NavigationActionPolicy.ALLOW;
                      } else {
                        print('URL cancelled ${uri.toString()}');
                        return NavigationActionPolicy.CANCEL;
                      }
                    },
                  ),
                  Align(alignment: Alignment.topRight, child: IconButton(onPressed: back, icon: const Icon(Icons.close))),
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
