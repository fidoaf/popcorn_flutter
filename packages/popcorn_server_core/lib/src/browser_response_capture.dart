final class BrowserCaptureOptions {
  const BrowserCaptureOptions({
    this.timeout = const Duration(seconds: 25),
    this.userAgent = '',
    this.javascriptEnabled = true,
    this.cacheEnabled = false,
    this.viewportWidth = 1280,
    this.viewportHeight = 800,
    this.beforeLoadScripts = const [],
  });

  final Duration timeout;
  final String userAgent;
  final bool javascriptEnabled;
  final bool cacheEnabled;
  final int viewportWidth;
  final int viewportHeight;
  final List<String> beforeLoadScripts;
}

final class BrowserCapturedResponse {
  const BrowserCapturedResponse({required this.uri, required this.statusCode, required this.body});

  final Uri uri;
  final int statusCode;
  final String body;
}

abstract interface class BrowserResponseCaptureClient {
  Future<BrowserCapturedResponse> captureFirstResponse({
    required Uri navigationUri,
    required bool Function(Uri uri, int statusCode) matches,
    required BrowserCaptureOptions options,
  });

  Future<void> close();
}

const cinesrcNavigationHardeningScript = r'''
(() => {
  try {
    const blocked = ['about:blank'];
    const wrap = (obj, prop) => {
      try {
        const original = obj[prop];
        if (typeof original === 'function') {
          obj[prop] = function (url) {
            if (blocked.some((item) => String(url).includes(item))) return;
            return original.call(this, url);
          };
        }
      } catch (_) {}
    };
    wrap(window.location, 'assign');
    wrap(window.location, 'replace');
    window.open = () => null;
    Object.defineProperty(window, 'name', { get: () => '', configurable: true });
    history.pushState = function () {};
    history.replaceState = function () {};
  } catch (_) {}
  try { Object.defineProperty(navigator, 'webdriver', { get: () => false }); } catch (_) {}
  try {
    window.alert = () => null;
    window.confirm = () => true;
    window.prompt = () => null;
  } catch (_) {}
})();
''';
