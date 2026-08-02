import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';

/// Contract for persisting the user's "continue watching" history across app
/// launches.
///
/// Consumers depend on this abstraction rather than any concrete storage
/// mechanism, keeping the feature open for extension (e.g. a remote backend)
/// without modification.
abstract interface class WatchHistoryRepository {
  /// Loads the persisted history, or an empty list when none is stored.
  Future<List<WatchHistoryEntry>> load();

  /// Persists the given [entries], replacing any previously stored set.
  Future<void> save(List<WatchHistoryEntry> entries);
}
