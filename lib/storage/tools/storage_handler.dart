import 'dart:convert';

import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/storage/core/model/application_storage.dart';
import 'package:popcorn_flutter/storage/core/model/media_storage.dart';

abstract class MediaStorageClient implements IMediaStorage {
  static final _prefs = ServiceLocator.get<ApplicationStorage>();

  const MediaStorageClient();

  String get key;

  @override
  Future<bool> add(MediaInfo info) async {
    final rawList = _prefs.getStringList(key) ?? [];
    rawList.add(jsonEncode(info.toJson()));
    return _prefs.setStringList(key, rawList);
  }

  @override
  Future<bool> remove(MediaInfo info) async {
    final rawList = _prefs.getStringList(key) ?? [];
    final newList = rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).where((fav) => fav != info);
    final removed = await _prefs.setStringList(key, newList.map((i) => jsonEncode(i.toJson())).toList());
    return removed;
  }

  @override
  List<MediaInfo> getAll() {
    final rawList = _prefs.getStringList(key) ?? [];
    return rawList.map((text) => MediaInfo.fromJson(jsonDecode(text))).toList();
  }

  @override
  Future<bool> clear() async {
    return _prefs.clear();
  }
}
