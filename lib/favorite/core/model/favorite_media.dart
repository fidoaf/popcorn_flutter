import 'package:popcorn_flutter/search/core/model/media_info.dart';

class FavoriteMediaInfo {
  final String id;
  final String name;
  final String? imageUrl;
  const FavoriteMediaInfo({required this.id, required this.name, required this.imageUrl});

  factory FavoriteMediaInfo.fromInfo(MediaInfo info) {
    return FavoriteMediaInfo(id: info.id, name: info.name, imageUrl: info.image?.url);
  }

  factory FavoriteMediaInfo.fromJson(Map<String, dynamic> data) {
    return FavoriteMediaInfo(id: data['id'], name: data['name'], imageUrl: data['image']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': imageUrl,
    };
  }

  @override
  operator ==(Object other) {
    return other is FavoriteMediaInfo && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
