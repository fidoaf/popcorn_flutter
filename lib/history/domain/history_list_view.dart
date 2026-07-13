import 'package:popcorn_flutter/history/domain/history_item.dart';
import 'package:popcorn_flutter/history/domain/history_item_view.dart';

abstract class HistoryListView {
  Future<Iterable<HistoryItem>> fetchHistory();
  HistoryItemView renderItem(HistoryItem item);
}
