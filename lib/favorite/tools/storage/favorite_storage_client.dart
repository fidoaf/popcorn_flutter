import 'dart:convert';

import 'package:popcorn_flutter/favorite/core/model/favorite_media.dart';
import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStorageClient implements IFavoriteStorage {
  static const _favKey = 'favorites';

  const FavoriteStorageClient();

  @override
  Future<bool> add(FavoriteMediaInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    rawList.add(jsonEncode(info.toJson()));
    return prefs.setStringList(_favKey, rawList);
  }

  @override
  Future<bool> remove(FavoriteMediaInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    final newList = rawList.map((text) => FavoriteMediaInfo.fromJson(jsonDecode(text))).where((fav) => fav != info);
    return prefs.setStringList(_favKey, newList.map((i) => jsonEncode(i.toJson())).toList());
  }

  @override
  Future<List<FavoriteMediaInfo>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_favKey) ?? [];
    return rawList.map((text) => FavoriteMediaInfo.fromJson(jsonDecode(text))).toList();
  }
}
