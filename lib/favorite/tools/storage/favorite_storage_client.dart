import 'dart:convert';

import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStorageClient implements IFavoriteStorage {
  static const _favKey = 'favorites';

  const FavoriteStorageClient();

  @override
  Future<bool> add(MediaInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    rawList.add(jsonEncode(info.toJson()));
    return prefs.setStringList(_favKey, rawList);
  }

  @override
  Future<bool> remove(MediaInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    final newList = rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).where((fav) => fav != info);
    return prefs.setStringList(_favKey, newList.map((i) => jsonEncode(i.toJson())).toList());
  }

  @override
  Future<List<MediaInfo>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    return rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).toList();
  }

  @override
  Future<bool> clear() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.clear();
  }
}
