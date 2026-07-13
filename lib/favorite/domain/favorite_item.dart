import 'package:popcorn_flutter/common/domain/media_title.dart';

class FavoriteItem {
  final MediaTitle title;
  final String year;
  const FavoriteItem._({required this.title, required this.year});

  factory FavoriteItem.create({required String title, required String year}) {
    return FavoriteItem._(
      title: MediaTitle.create(text: title),
      year: year,
    );
  }
}
