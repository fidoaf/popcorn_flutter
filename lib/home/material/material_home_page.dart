import 'package:flutter/material.dart';
import 'package:popcorn_flutter/favorite/material/material_favorite_list_view.dart';
import 'package:popcorn_flutter/history/material/material_history_list_view.dart';
import 'package:popcorn_flutter/home/domain/home_page.dart';

class MaterialHomePage extends StatelessWidget implements HomePage {
  const MaterialHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('HOME')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: renderFavorites()),
          Flexible(child: renderWatchHistory()),
        ],
      ),
    );
  }

  @override
  MaterialFavoriteListView renderFavorites() {
    return const MaterialFavoriteListView();
  }

  @override
  MaterialHistoryListView renderWatchHistory() {
    return const MaterialHistoryListView();
  }

  @override
  void search(String text) {
    // TODO: implement search
  }
}
