import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

final class FlutterBrowserProviderAdapter implements BrowserResponseCaptureClient, SameOriginBrowserFetchClient {
  static const _handlerName = 'popcornBrowserResponse';

  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _controller;
  Completer<InAppWebViewController>? _controllerReady;
  Completer<void>? _pageLoad;
  Completer<BrowserCapturedResponse>? _pendingCapture;
  bool Function(Uri uri, int statusCode)? _pendingMatcher;
  Uri? _currentPageUri;
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _closeFuture;
  bool _closed = false;

  @override
  Future<BrowserCapturedResponse> captureFirstResponse({
    required Uri navigationUri,
    required bool Function(Uri uri, int statusCode) matches,
    required BrowserCaptureOptions options,
  }) => _serialize(() async {
    final stopwatch = Stopwatch()..start();
    final controller = await _ensureController(initialSize: Size(options.viewportWidth.toDouble(), options.viewportHeight.toDouble()));
    final capture = Completer<BrowserCapturedResponse>();
    unawaited(capture.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    _pendingCapture = capture;
    _pendingMatcher = matches;
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          javaScriptEnabled: options.javascriptEnabled,
          cacheEnabled: options.cacheEnabled,
          userAgent: options.userAgent.isEmpty ? null : options.userAgent,
        ),
      );
      await controller.removeAllUserScripts();
      for (final script in [...options.beforeLoadScripts, _responseCaptureScript]) {
        await controller.addUserScript(
          userScript: UserScript(source: script, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
        );
      }
      await _loadUrl(controller, navigationUri, _remaining(options.timeout, stopwatch), forceReload: true);
      return await capture.future.timeout(_remaining(options.timeout, stopwatch));
    } finally {
      if (identical(_pendingCapture, capture)) _pendingCapture = null;
      _pendingMatcher = null;
    }
  });

  @override
  Future<ProviderHttpResponse> fetch(Uri uri, {required Map<String, String> headers, required Duration timeout}) => _serialize(() async {
    final stopwatch = Stopwatch()..start();
    final controller = await _ensureController();
    final userAgent = headers['User-Agent'];
    if (userAgent != null) {
      await controller.setSettings(settings: InAppWebViewSettings(javaScriptEnabled: true, cacheEnabled: false, userAgent: userAgent));
    }
    if (_currentPageUri?.origin != uri.origin) {
      await _loadUrl(controller, uri.replace(path: '/', query: null, fragment: null), _remaining(timeout, stopwatch));
    }
    final result = await controller
        .callAsyncJavaScript(
          functionBody: r'''
        const response = await fetch(url, {
          method: 'GET',
          credentials: 'include',
          headers: requestHeaders
        });
        const body = await response.text();
        const responseHeaders = {};
        response.headers.forEach((value, name) => {
          responseHeaders[name] = value;
        });
        return {
          statusCode: response.status,
          reasonPhrase: response.statusText,
          body,
          headers: responseHeaders
        };
      ''',
          arguments: {'url': uri.toString(), 'requestHeaders': headers},
        )
        .timeout(_remaining(timeout, stopwatch));
    if (result?.error case final error?) {
      throw ProviderHttpException('Browser fetch failed: $error');
    }
    final value = result?.value;
    if (value is! Map || value['statusCode'] is! num || value['body'] is! String) {
      throw const ProviderHttpException('Browser fetch returned an invalid response');
    }
    final responseHeaders = <String, String>{};
    final rawHeaders = value['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        if (entry.key is String && entry.value is String) {
          responseHeaders[entry.key as String] = entry.value as String;
        }
      }
    }
    return ProviderHttpResponse(
      statusCode: (value['statusCode'] as num).toInt(),
      reasonPhrase: value['reasonPhrase'] is String ? value['reasonPhrase'] as String : '',
      body: value['body'] as String,
      headers: responseHeaders,
    );
  });

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    final controllerReady = _controllerReady;
    if (controllerReady != null && !controllerReady.isCompleted) {
      controllerReady.completeError(StateError('Browser provider adapter closed.'));
    }
    final capture = _pendingCapture;
    if (capture != null && !capture.isCompleted) {
      capture.completeError(StateError('Browser provider adapter closed.'));
    }
    final pageLoad = _pageLoad;
    if (pageLoad != null && !pageLoad.isCompleted) {
      pageLoad.completeError(StateError('Browser provider adapter closed.'));
    }
    await _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
  }

  Future<InAppWebViewController> _ensureController({Size initialSize = const Size(1280, 800)}) async {
    if (_closed) throw StateError('Browser provider adapter is closed.');
    final existing = _controller;
    if (existing != null) return existing;
    var ready = _controllerReady;
    if (ready == null) {
      ready = Completer<InAppWebViewController>();
      _controllerReady = ready;
      unawaited(ready.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      final headlessWebView = HeadlessInAppWebView(
        initialSize: initialSize,
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, cacheEnabled: false),
        onWebViewCreated: (controller) {
          _controller = controller;
          controller.addJavaScriptHandler(handlerName: _handlerName, callback: _onCapturedResponse);
          if (!ready!.isCompleted) ready.complete(controller);
        },
        onLoadStart: (controller, url) {
          _currentPageUri = null;
        },
        onLoadStop: (controller, url) {
          _currentPageUri = Uri.tryParse(url?.toString() ?? '');
          final pageLoad = _pageLoad;
          if (pageLoad != null && !pageLoad.isCompleted) pageLoad.complete();
        },
        onLoadError: (controller, url, code, message) {
          final pageLoad = _pageLoad;
          if (pageLoad != null && !pageLoad.isCompleted) {
            pageLoad.completeError(StateError('Browser navigation failed ($code): $message'));
          }
        },
      );
      _headlessWebView = headlessWebView;
      try {
        await headlessWebView.run();
      } on Object catch (error, stackTrace) {
        if (!ready.isCompleted) ready.completeError(error, stackTrace);
        _headlessWebView = null;
        _controllerReady = null;
        await headlessWebView.dispose();
        rethrow;
      }
    }
    return _controller ?? await ready.future.timeout(const Duration(seconds: 15));
  }

  Future<void> _loadUrl(InAppWebViewController controller, Uri uri, Duration timeout, {bool forceReload = false}) async {
    final loadedUri = _currentPageUri;
    if (!forceReload && loadedUri?.toString() == uri.toString()) return;
    final pageLoad = Completer<void>();
    unawaited(pageLoad.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    _pageLoad = pageLoad;
    try {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
      await pageLoad.future.timeout(timeout);
    } finally {
      if (identical(_pageLoad, pageLoad)) _pageLoad = null;
    }
  }

  Future<Object?> _onCapturedResponse(List<dynamic> arguments) async {
    if (arguments.length < 3) return null;
    final uri = Uri.tryParse('${arguments[0]}');
    final statusCode = arguments[1];
    final body = arguments[2];
    final capture = _pendingCapture;
    final matcher = _pendingMatcher;
    if (uri == null || statusCode is! num || body is! String || capture == null || matcher == null || !matcher(uri, statusCode.toInt())) {
      return null;
    }
    final response = BrowserCapturedResponse(uri: uri, statusCode: statusCode.toInt(), body: body);
    if (!capture.isCompleted) capture.complete(response);
    return null;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (_closed) return Future.error(StateError('Browser provider adapter is closed.'));
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Duration _remaining(Duration timeout, Stopwatch stopwatch) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException('Browser operation timed out.');
    return remaining;
  }

  static const _responseCaptureScript = r'''
    (() => {
      const emit = (url, statusCode, body) => {
        if (typeof body !== 'string' || body.length > 8388608) return;
        const bridge = window.flutter_inappwebview;
        if (bridge && typeof bridge.callHandler === 'function') {
          bridge.callHandler('popcornBrowserResponse', url, statusCode, body);
        }
      };
      const isPlaylist = (rawUrl) => {
        try {
          const url = new URL(rawUrl, document.baseURI);
          return url.origin === location.origin &&
            url.pathname.startsWith('/api/playlist/') &&
            url.pathname.toLowerCase().endsWith('.m3u8');
        } catch (_) {
          return false;
        }
      };
      const originalFetch = window.fetch;
      if (typeof originalFetch === 'function') {
        window.fetch = function (...args) {
          const requestUrl = args[0] instanceof Request ? args[0].url : args[0];
          return originalFetch.apply(this, args).then((response) => {
            if (isPlaylist(response.url || requestUrl)) {
              response.clone().text().then((body) => {
                emit(response.url || String(requestUrl), response.status, body);
              }).catch(() => {});
            }
            return response;
          });
        };
      }
      const originalOpen = XMLHttpRequest.prototype.open;
      const originalSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function (method, url, ...rest) {
        this.__popcornRequestUrl = new URL(url, document.baseURI).href;
        return originalOpen.call(this, method, url, ...rest);
      };
      XMLHttpRequest.prototype.send = function (...args) {
        this.addEventListener('load', () => {
          const requestUrl = this.__popcornRequestUrl;
          if (!isPlaylist(requestUrl)) return;
          let body = '';
          try {
            body = typeof this.responseText === 'string'
              ? this.responseText
              : typeof this.response === 'string'
                ? this.response
                : JSON.stringify(this.response);
          } catch (_) {}
          emit(requestUrl, this.status, body);
        }, { once: true });
        return originalSend.apply(this, args);
      };
    })();
  ''';
}
