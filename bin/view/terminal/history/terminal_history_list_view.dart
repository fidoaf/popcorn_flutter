import 'package:popcorn_flutter/history/domain/history_item.dart';
import 'package:popcorn_flutter/history/domain/history_item_view.dart';
import 'package:popcorn_flutter/history/domain/history_list_view.dart';

class TerminalHistoryListView implements HistoryListView {
  @override
  Future<Iterable<HistoryItem>> fetchHistory() async {
    return <HistoryItem>[];
  }

  @override
  HistoryItemView renderItem(HistoryItem item) {
    // TODO: implement renderItem
    throw UnimplementedError();
  }
}
