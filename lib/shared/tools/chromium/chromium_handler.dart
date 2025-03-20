import 'dart:io';

import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/shared/tools/chromium/browser.dart';
import 'package:puppeteer/puppeteer.dart';

class ChromiumHandler {
  static const _protocol = 'http';
  static const String _domain = 'localhost';
  static const int _port = 56789;

  static final BrowserType _browserType = BrowserType.fromString(ServiceLocator.configuration.browser);
  static const List<String> _chromeArgs = [
    '--remote-debugging-port=$_port',
    '--ash-enable-night-light',
    '--disable-background-mode',
    '--disable-translate',
    '--disable-notifications',
    '--block-new-web-contents',
    '--start-maximized',
    '--chrome-frame',
    ' --kiosk',
  ];

  static Process? _process;
  static Browser? _browser;
  static Page? _page;

  static final ChromiumHandler _singleton = ChromiumHandler._internal();

  factory ChromiumHandler() {
    return _singleton;
  }

  ChromiumHandler._internal();

  String get _chromePath => _browserType.path;

  Future<bool> launch(String url) async {
    _process ??= await Process.start(
      _chromePath,
      _chromeArgs,
    );

    _browser ??= await puppeteer.connect(
      browserUrl: "$_protocol://$_domain:$_port",
      defaultViewport: DeviceViewport(width: double.maxFinite.toInt(), height: double.maxFinite.toInt()),
    );

    // Open a new tab
    final currentBrowser = _browser;
    if (currentBrowser == null) {
      return false;
    } else {
      final needsInitialization = _page == null;
      _page ??= (await currentBrowser.pages).first;

      final currentPage = _page;
      if (currentPage == null) {
        return false;
      } else {
        if (needsInitialization) {
          // Restart
          currentBrowser.onTargetDestroyed.listen((_) {
            _process = _browser = _page = null;
          });
          // Allow interception
          currentPage.setRequestInterception(true);
          // Block some requests depending on heuristics
          currentPage.onRequest.listen(
            (event) async {
              print(event.url);
              // if (whitelabel.any((p) => event.url.contains(p)))
              if (event.url.contains('ads')) {
                await event.abort();
              } else {
                await event.continueRequest();
              }
            },
          );
          // Block dialogs
          currentPage.onDialog.listen(
            (event) async {
              event.dismiss();
            },
          );
        }

        // Go to a page and wait to be fully loaded
        final response = await currentPage.goto(url, wait: Until.networkIdle);

        return response.ok;
      }
    }
  }
}
