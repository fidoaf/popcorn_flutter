import 'dart:convert';

import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/history/core/model/history_media_info.dart';
import 'package:popcorn_flutter/history/core/model/history_storage.dart';
import 'package:popcorn_flutter/player/core/model/media_player_request.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/storage/core/model/application_storage.dart';

class HistoryStorageClient extends IHistoryStorage {
  static final _prefs = ServiceLocator.get<ApplicationStorage>();

  const HistoryStorageClient();

  @override
  String get key => 'history';

  String _getItemHistoryKey() {
    return '$key-123';
  }

  @override
  Future<HistoryMediaInfo?> getItemHistory(MediaPlayerRequest request) async {
    final raw = _prefs.getString(_getItemHistoryKey());
    if (raw == null) {
      return null;
    } else {
      final data = jsonDecode(raw) as Map<String, dynamic>?;
      if (data == null) {
        return null;
      } else {
        switch (request.type) {
          case MediaType.movie:
            return HistoryMovieInfo();
          case MediaType.series:
            return HistorySeriesInfo(season: 1, episode: 1);
        }
      }
    }
  }
}
