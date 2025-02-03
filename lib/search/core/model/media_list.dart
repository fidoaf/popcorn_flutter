import 'package:popcorn_flutter/search/core/model/media_info.dart';

class MediaList {
  final List<MediaInfo> items;
  const MediaList({required this.items});

  const MediaList.empty() : this(items: const []);

  get length => items.length;
  MediaInfo operator [](int index) => items[index];
}
