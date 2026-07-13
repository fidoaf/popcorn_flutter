import 'package:flutter/material.dart';
import 'package:popcorn_flutter/history/domain/history_item.dart';
import 'package:popcorn_flutter/history/domain/history_item_view.dart';

class MaterialHistoryItemView extends StatelessWidget implements HistoryItemView {
  final HistoryItem _item;
  const MaterialHistoryItemView({super.key, required HistoryItem item}) : _item = item;

  @override
  Widget build(BuildContext context) {
    return const Text('data');
  }

  @override
  HistoryItem get item => _item;
}
