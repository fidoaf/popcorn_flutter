import 'package:flutter/material.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_item.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_item_view.dart';

class MaterialFavoriteItemView extends StatelessWidget implements FavoriteItemView {
  final FavoriteItem _item;
  const MaterialFavoriteItemView({super.key, required FavoriteItem item}) : _item = item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${_item.title}'),
        Text(_item.year),
      ],
    );
  }

  @override
  FavoriteItem get item => _item;
}
