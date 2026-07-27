import 'dart:convert';

import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FavoritesRepository] backed by `shared_preferences`, storing the favorites
/// as a single JSON-encoded list under [_storageKey].
class SharedPreferencesFavoritesRepository implements FavoritesRepository {
  static const String _storageKey = 'favorites.items';

  @override
  Future<List<FavoriteMedia>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((entry) => FavoriteMedia.fromJson(entry as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupted or incompatible data – start from an empty set.
      return const [];
    }
  }

  @override
  Future<void> save(List<FavoriteMedia> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(favorites.map((favorite) => favorite.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
