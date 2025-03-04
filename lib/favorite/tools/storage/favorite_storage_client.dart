import 'dart:convert';

import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/favorite/core/model/favorite_storage.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStorageClient implements IFavoriteStorage {
  static const _favKey = 'favorites';

  static final _prefs = ServiceLocator.get<SharedPreferences>();

  const FavoriteStorageClient();

  @override
  Future<bool> add(MediaInfo info) async {
    final rawList = _prefs.getStringList(_favKey) ?? [];
    rawList.add(jsonEncode(info.toJson()));
    return _prefs.setStringList(_favKey, rawList);
  }

  @override
  Future<bool> remove(MediaInfo info) async {
    final rawList = _prefs.getStringList(_favKey) ?? [];
    final newList = rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).where((fav) => fav != info);
    final removed = await _prefs.setStringList(_favKey, newList.map((i) => jsonEncode(i.toJson())).toList());
    return removed;
  }

  @override
  List<MediaInfo> getAll() {
    final rawList = _prefs.getStringList(_favKey) ?? [];
    return rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).toList();
  }

  @override
  Future<bool> clear() async {
    return _prefs.clear();
  }
}
