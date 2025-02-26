import 'package:popcorn_flutter/search/core/model/media_info.dart';

abstract class IFavoriteStorage {
  Future<bool> add(MediaInfo info);
  Future<bool> remove(MediaInfo info);

  List<MediaInfo> getAll();

  Future<bool> clear();
}
