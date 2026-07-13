import 'package:popcorn_flutter/favorite/domain/favorite_item.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_item_view.dart';

abstract class FavoriteListView {
  Future<Iterable<FavoriteItem>> fetchFavorites();
  FavoriteItemView renderItem(FavoriteItem item);
}
