import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-title playback positions so the native player can offer a
/// "resume from where you left off" prompt, mirroring the `localStorage`
/// behaviour of the reference HTML player.
///
/// Entries are keyed by a caller-supplied identifier (typically the stream
/// URL). Stale entries are pruned by age and by count on every write.
final class ResumeStore {
  const ResumeStore._();

  static const _key = 'vsp_native_positions';
  static const _maxEntries = 80;
  static const _maxAge = Duration(days: 30);

  /// Minimum elapsed time before a position is worth remembering.
  static const _minPosition = Duration(seconds: 60);

  /// How close to the end still counts as "finished" (so no resume is offered).
  static const _endGuard = Duration(seconds: 120);

  static Future<Map<String, dynamic>> _all(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Returns the resumable position for [id], or `null` when there is nothing
  /// worth resuming (too early, too close to the end, or unknown).
  static Future<Duration?> read(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = (await _all(prefs))[id];
    if (entry is! Map) return null;
    final seconds = (entry['t'] as num?)?.toInt() ?? 0;
    final duration = (entry['d'] as num?)?.toInt() ?? 0;
    final position = Duration(seconds: seconds);
    if (position < _minPosition) return null;
    if (duration > 0 && position > Duration(seconds: duration) - _endGuard) return null;
    return position;
  }

  /// Records [position] (within a media of [total] length) for [id], pruning
  /// stale and overflowing entries.
  static Future<void> write(String id, Duration position, Duration total) async {
    if (position < _minPosition) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await _all(prefs);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    all[id] = {'t': position.inSeconds, 'd': total.inSeconds, 'at': now};

    all.removeWhere((_, value) => value is Map && now - ((value['at'] as num?)?.toInt() ?? 0) > _maxAge.inSeconds);
    if (all.length > _maxEntries) {
      final keys = all.keys.toList()
        ..sort((a, b) {
          final at = (all[a] as Map)['at'] as num? ?? 0;
          final bt = (all[b] as Map)['at'] as num? ?? 0;
          return at.compareTo(bt);
        });
      for (final key in keys.take(all.length - _maxEntries)) {
        all.remove(key);
      }
    }
    await prefs.setString(_key, jsonEncode(all));
  }

  /// Forgets any stored position for [id] (e.g. after playback completes or the
  /// viewer chooses to start over).
  static Future<void> clear(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all(prefs);
    if (all.remove(id) != null) await prefs.setString(_key, jsonEncode(all));
  }
}
