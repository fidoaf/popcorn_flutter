import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Holds the user's "continue watching" history and keeps it in sync with the
/// [WatchHistoryRepository].
///
/// Depends only on the [WatchHistoryRepository] abstraction, so it works with
/// any storage backend and is trivial to unit test. Entries are ordered
/// most-recently-watched first and capped at [maxEntries].
class WatchHistoryController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  WatchHistoryController({required WatchHistoryRepository repository, this.maxEntries = 50}) : _repository = repository {
    _load();
  }

  final WatchHistoryRepository _repository;

  /// The most entries to retain; older ones are dropped when the cap is hit.
  final int maxEntries;

  List<WatchHistoryEntry> _entries = const [];

  /// The history, most recently watched first.
  List<WatchHistoryEntry> get entries => List.unmodifiable(_entries);

  /// Records that playback of [media] (of [mediaType]) started, moving it to
  /// the front of the history and persisting the change. For TV series,
  /// [season]/[episode] capture the episode left off at.
  Future<void> record(MediaItem media, MediaType mediaType, {int? season, int? episode}) async {
    final entry = WatchHistoryEntry(item: media, type: mediaType, season: season, episode: episode, watchedAt: DateTime.now());
    final withoutExisting = _entries.where((existing) => !existing.matches(mediaType, media.id));
    _entries = [entry, ...withoutExisting].take(maxEntries).toList();
    notifyListeners();
    await _repository.save(_entries);
  }

  /// Removes the entry [id] of [type] from the history and persists the change.
  Future<void> remove(MediaType type, int id) async {
    if (!_entries.any((entry) => entry.matches(type, id))) return;
    _entries = _entries.where((entry) => !entry.matches(type, id)).toList();
    notifyListeners();
    await _repository.save(_entries);
  }

  Future<void> _load() async {
    final loaded = List.of(await _repository.load());
    loaded.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    _entries = loaded.take(maxEntries).toList();
    notifyListeners();
  }
}
