import 'package:flutter/material.dart';
import 'package:popcorn_flutter/common/application/result.dart';
import 'package:popcorn_flutter/favorite/application/favorite_list_fetcher.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_item.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_list_view.dart';
import 'package:popcorn_flutter/favorite/material/material_favorite_item_view.dart';
import 'package:popcorn_flutter/page/material/material_list_view.dart';

class MaterialFavoriteListView extends MaterialListView<Iterable<FavoriteItem>> implements FavoriteListView {
  const MaterialFavoriteListView({super.key});

  @override
  Future<Iterable<FavoriteItem>> fetchFavorites() async {
    final result = await FavoriteListFetcher().call(());
    if (result is OK<Iterable<FavoriteItem>>) {
      return result.value;
    }

    return [];
  }

  @override
  MaterialFavoriteItemView renderItem(FavoriteItem item) {
    return MaterialFavoriteItemView(item: item);
  }

  @override
  Future<Iterable<FavoriteItem>> fetcher() {
    return fetchFavorites();
  }

  @override
  Widget renderer(BuildContext context, Iterable<FavoriteItem> value) {
    return ListView.separated(
      itemBuilder: (context, index) => Text('$index'),
      separatorBuilder: (context, index) => const Divider(),
      itemCount: value.length,
    );
  }

  @override
  void onSuccessAction(BuildContext context, value) {
    // TODO: implement action
  }

  @override
  void onErrorAction(BuildContext context) {
    // TODO: implement onErrorAction
  }
}
