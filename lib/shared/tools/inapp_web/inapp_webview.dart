import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';
import 'package:popcorn_flutter/shared/core/model/web_renderer.dart';

class InAppWebRenderer implements IWebRenderer {

    static final InAppWebRenderer _singleton = InAppWebRenderer._internal();

  factory InAppWebRenderer() {
    return _singleton;
  }

  InAppWebRenderer._internal();



  @override
  Future<bool> check(String url) async {
    // final response = await get(Uri.parse(url));
    // return response.statusCode == HttpStatus.accepted;
    return true;
  }

  @override
  Future<bool> launch(String url) async {
    Navigator.push(
      NavigationService.navigatorKey.currentContext!,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(),
              body: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri("https://vidsrc.xyz/embed/tt1300854/"),
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if ([
                    'vidsrc.xyz',
                    'edgedeliverynetwork.com',
                  ].contains(uri?.host)) {
                    return NavigationActionPolicy.ALLOW;
                  } else {
                    print('ZZZ ${uri.toString()}');
                    return NavigationActionPolicy.CANCEL;
                  }
                },
              ),
            ),
      ),
    );
    return true;
  }
}
