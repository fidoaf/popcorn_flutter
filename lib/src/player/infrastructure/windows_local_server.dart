import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Owns only the server it starts. An existing authenticated server is reused.
final class WindowsLocalServer {
  WindowsLocalServer({
    required this.bundleDirectory,
    required this.token,
    this.port = 3000,
    this.startupTimeout = const Duration(seconds: 30),
    this.onUnexpectedExit,
  });

  static const _tokenKey = 'windows.localPlayerServerToken';
  final Directory bundleDirectory;
  final String token;
  final int port;
  final Duration startupTimeout;
  final void Function(int code)? onUnexpectedExit;
  Process? _process;
  bool _stopping = false;

  String get serverUrl => 'http://127.0.0.1:$port';

  static Future<String> loadToken(SharedPreferences preferences) async {
    final existing = preferences.getString(_tokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final token = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    if (!await preferences.setString(_tokenKey, token)) throw StateError('Unable to save the local server token.');
    return token;
  }

  Future<bool> _isReady(http.Client client) async {
    try {
      final health = await client.get(Uri.parse('$serverUrl/health')).timeout(const Duration(seconds: 5));
      if (health.statusCode != 200 || health.body.trim() != 'ok') {
        throw StateError('Port $port is occupied by a different service.');
      }
      final providers = await client.get(Uri.parse('$serverUrl/providers'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 5));
      if (providers.statusCode != 200) throw StateError('The local player server on port $port rejected authentication.');
      final body = jsonDecode(providers.body);
      if (body is! Map || body['providers'] is! List || (body['providers'] as List).isEmpty || body['defaultProvider'] is! String) {
        throw StateError('The local server on port $port is not a compatible player server.');
      }
      return true;
    } on http.ClientException catch (error) {
      if (_process != null) debugPrint('[LocalServer] Waiting for readiness: $error');
      return false;
    } on TimeoutException {
      throw StateError('The local server on port $port is not responding.');
    }
  }

  Future<void> start() async {
    if (_process != null || _stopping) throw StateError('This local server owner has already been started or stopped.');
    final client = http.Client();
    try {
      if (await _isReady(client)) return;
      final node = File('${bundleDirectory.path}\\node.exe');
      final script = File('${bundleDirectory.path}\\server\\server.js');
      final chromeManifest = File('${bundleDirectory.path}\\chrome-path.txt');
      if (!await node.exists() || !await script.exists() || !await chromeManifest.exists()) {
        throw StateError('The local server bundle is missing. Install a packaged Windows build, or run tool\\bundle_windows_server.ps1 and rebuild.');
      }
      final chrome = File('${bundleDirectory.path}\\${(await chromeManifest.readAsString()).trim()}');
      if (!await chrome.exists()) throw StateError('The bundled Chromium executable is missing.');
      final process = await Process.start(
        node.path,
        [script.path],
        workingDirectory: script.parent.path,
        environment: {
          'PORT': '$port',
          'HOST': '127.0.0.1',
          'API_TOKENS': token,
          'POPCORN_MANAGED_SERVER': '1',
          'PUPPETEER_EXECUTABLE_PATH': chrome.path,
          'NODE_ENV': 'production',
        },
      );
      _process = process;
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => debugPrint('[LocalServer] $line'));
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => debugPrint('[LocalServer] $line'));
      int? exitCode;
      unawaited(
        process.exitCode.then((code) {
          exitCode = code;
          if (!_stopping) {
            debugPrint('[LocalServer] Server exited unexpectedly (code $code).');
            onUnexpectedExit?.call(code);
          }
        }),
      );
      final deadline = DateTime.now().add(startupTimeout);
      while (DateTime.now().isBefore(deadline)) {
        if (exitCode != null) throw StateError('The bundled player server exited with code $exitCode.');
        if (await _isReady(client)) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      throw StateError('The bundled player server did not become ready within ${startupTimeout.inSeconds} seconds.');
    } catch (_) {
      await stop();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> stop() async {
    _stopping = true;
    final process = _process;
    if (process == null) return;
    _process = null;
    await process.stdin.close();
    try {
      await process.exitCode.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      debugPrint('[LocalServer] Graceful shutdown timed out; terminating owned process tree ${process.pid}.');
      final result = await Process.run('taskkill.exe', ['/PID', '${process.pid}', '/T', '/F']);
      if (result.exitCode != 0) throw StateError('Unable to stop local player server: ${result.stderr}');
    }
  }
}
