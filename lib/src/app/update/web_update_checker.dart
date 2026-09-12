import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Polls the web build's `version.json` to detect when a newer build has been
/// deployed, so the UI can prompt the user to reload.
///
/// The first successful fetch is captured as the baseline; any later value that
/// differs flips [updateAvailable] to `true` and stops polling.
class WebUpdateChecker extends ChangeNotifier {
  WebUpdateChecker({this.pollInterval = const Duration(minutes: 5), http.Client? client}) : _client = client ?? http.Client();

  final Duration pollInterval;
  final http.Client _client;

  Timer? _timer;
  String? _baseline;
  bool _updateAvailable = false;
  bool _disposed = false;

  bool get updateAvailable => _updateAvailable;

  /// Captures the current deployed version and begins periodic polling.
  Future<void> start() async {
    _baseline ??= await _fetchVersion();
    _timer ??= Timer.periodic(pollInterval, (_) => _check());
  }

  /// Forces an immediate check (e.g. when the app is resumed or refocused).
  Future<void> checkNow() => _check();

  Future<void> _check() async {
    if (_disposed || _updateAvailable) return;
    final latest = await _fetchVersion();
    if (latest == null) return;
    _baseline ??= latest;
    if (latest != _baseline) {
      _updateAvailable = true;
      _timer?.cancel();
      _timer = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> _fetchVersion() async {
    try {
      // Cache-bust so proxies/browsers don't hand back the cached copy.
      final uri = Uri.parse('version.json?ts=${DateTime.now().millisecondsSinceEpoch}');
      final response = await _client.get(uri, headers: const {'cache-control': 'no-cache'});
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final version = json['version']?.toString() ?? '';
      final build = json['build_number']?.toString() ?? '';
      final combined = '$version+$build';
      // Fall back to the raw body if neither field is present.
      return combined == '+' ? response.body : combined;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
