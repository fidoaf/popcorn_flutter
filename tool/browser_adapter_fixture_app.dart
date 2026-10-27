import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/player/infrastructure/flutter_browser_provider_adapter.dart';
import 'package:popcorn_server_core/popcorn_server_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Browser fixture test'))),
    ),
  );
  unawaited(_runFixture());
}

Future<void> _runFixture() async {
  HttpServer? fixture;
  final adapter = FlutterBrowserProviderAdapter();
  var result = 0;
  try {
    fixture = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fixture.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/embed':
          response.headers.contentType = ContentType.html;
          response.write('<script>fetch("/api/playlist/test.m3u8").then(r => r.text())</script>');
        case '/api/playlist/test.m3u8':
          response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
          response.write('#EXTM3U\n#EXTINF:4.0,\nsegment.ts\n#EXT-X-ENDLIST\n');
        case '/api/data':
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({'ok': true}));
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });

    final origin = Uri.parse('http://${fixture.address.address}:${fixture.port}');
    final captured = await adapter.captureFirstResponse(
      navigationUri: origin.resolve('/embed'),
      matches: (uri, statusCode) => uri.path == '/api/playlist/test.m3u8' && statusCode == HttpStatus.ok,
      options: const BrowserCaptureOptions(timeout: Duration(seconds: 20)),
    );
    if (!captured.body.startsWith('#EXTM3U')) {
      throw StateError('Browser bridge returned an invalid fixture playlist.');
    }

    final fetched = await adapter.fetch(origin.resolve('/api/data'), headers: const {'Accept': 'application/json'}, timeout: const Duration(seconds: 10));
    if (fetched.statusCode != HttpStatus.ok || jsonDecode(fetched.body)['ok'] != true) {
      throw StateError('Same-origin browser fetch returned an invalid fixture response.');
    }
    stdout.writeln('BROWSER_ADAPTER_FIXTURE_PASS');
  } on Object catch (error, stackTrace) {
    result = 1;
    stderr.writeln('BROWSER_ADAPTER_FIXTURE_FAIL: $error\n$stackTrace');
  } finally {
    await adapter.close();
    await fixture?.close(force: true);
  }
  exit(result);
}
