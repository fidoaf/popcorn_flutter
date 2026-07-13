import 'package:flutter/material.dart';
import 'package:popcorn_flutter/history/domain/history_item.dart';
import 'package:popcorn_flutter/history/domain/history_list_view.dart';
import 'package:popcorn_flutter/history/material/material_history_item_view.dart';

class MaterialHistoryListView extends StatelessWidget implements HistoryListView {
  const MaterialHistoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fetchHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final list = snapshot.data ?? [];
          return Column(
            children: list.map((fav) => renderItem(fav)).toList(),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Future<Iterable<HistoryItem>> fetchHistory() async {
    return Future.delayed(const Duration(seconds: 5), () => <HistoryItem>[]);
  }

  @override
  MaterialHistoryItemView renderItem(HistoryItem item) {
    return MaterialHistoryItemView(item: item);
  }
}
