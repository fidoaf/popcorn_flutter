import 'package:popcorn_flutter/favorite/domain/favorite_list_view.dart';
import 'package:popcorn_flutter/history/domain/history_list_view.dart';
import 'package:popcorn_flutter/page/domain/view_page.dart';

abstract class HomePage implements ViewPage {
  void search(String text);
  FavoriteListView renderFavorites();
  HistoryListView renderWatchHistory();
}
