import 'dart:convert';

import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [WatchHistoryRepository] backed by `shared_preferences`, storing the history
/// as a single JSON-encoded list under [_storageKey].
class SharedPreferencesWatchHistoryRepository implements WatchHistoryRepository {
  static const String _storageKey = 'watch_history.items';

  @override
  Future<List<WatchHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((entry) => WatchHistoryEntry.fromJson(entry as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupted or incompatible data – start from an empty history.
      return const [];
    }
  }

  @override
  Future<void> save(List<WatchHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
