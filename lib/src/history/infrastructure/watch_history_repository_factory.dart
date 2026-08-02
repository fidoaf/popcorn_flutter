import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/history/infrastructure/shared_preferences_watch_history_repository.dart';

/// Builds the [WatchHistoryRepository] implementation used by the app.
abstract final class WatchHistoryRepositoryFactory {
  const WatchHistoryRepositoryFactory._();

  static WatchHistoryRepository create() => SharedPreferencesWatchHistoryRepository();
}
