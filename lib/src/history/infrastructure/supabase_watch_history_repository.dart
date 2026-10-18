import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [WatchHistoryRepository] backed by the Supabase `watch_history` table, scoped
/// to the signed-in user's profile.
///
/// Returns an empty list when signed out. [upsert] updates only one title's
/// history; entries are read back most-recently-watched first.
class SupabaseWatchHistoryRepository implements WatchHistoryRepository {
  SupabaseWatchHistoryRepository({required ProfileRepository profileRepository, required MediaSearchRepository mediaRepository, SupabaseClient? client})
    : _profiles = profileRepository,
      _catalog = mediaRepository,
      _client = client ?? Supabase.instance.client;

  static const String _table = 'watch_history';

  final ProfileRepository _profiles;
  final MediaSearchRepository _catalog;
  final Map<(MediaType, int), MediaItem> _mediaCache = {};
  final SupabaseClient _client;
  Future<void> _pending = Future.value();

  @override
  Future<List<WatchHistoryEntry>> load() async {
    final profile = await _profiles.activeProfile();
    if (profile == null) return const [];
    await _pending;
    final rows = await _client
        .from(_table)
        .select(
          'media_type,media_id,season,episode,watched_at,playback_provider,playback_source,audio_language,subtitle_selection,subtitle_delay_seconds,position_seconds',
        )
        .eq('profile_id', profile.id)
        .order('watched_at', ascending: false);
    return Future.wait(rows.map(_fromRow));
  }

  @override
  Future<void> upsert(WatchHistoryEntry entry) async {
    if (entry.item.title.isNotEmpty) _cacheMedia(entry.type, entry.item);
    final profileFuture = _profiles.activeProfile();
    final write = _pending.then((_) async {
      final profile = await profileFuture;
      if (profile == null) return;
      await _client.from(_table).upsert(_toRow(entry, profile.id), onConflict: 'profile_id,media_type,media_id');
    });
    _pending = write.catchError((Object _) {});
    await write;
  }

  @override
  Future<void> remove(WatchHistoryEntry entry) async {
    final profileFuture = _profiles.activeProfile();
    final write = _pending.then((_) async {
      final profile = await profileFuture;
      if (profile == null) return;
      await _client.from(_table).delete().eq('profile_id', profile.id).eq('media_type', entry.type.name).eq('media_id', entry.item.id);
    });
    _pending = write.catchError((Object _) {});
    await write;
  }

  Map<String, dynamic> _toRow(WatchHistoryEntry entry, String profileId) => {
    'profile_id': profileId,
    'media_type': entry.type.name,
    'media_id': entry.item.id,
    'season': entry.season,
    'episode': entry.episode,
    'playback_provider': entry.playback.provider,
    'playback_source': entry.playback.source,
    'audio_language': entry.playback.language,
    'subtitle_selection': entry.playback.subtitles,
    'subtitle_delay_seconds': entry.playback.subtitleDelaySeconds,
    'position_seconds': entry.playback.positionSeconds,
    'watched_at': entry.watchedAt.toIso8601String(),
  };

  void _cacheMedia(MediaType type, MediaItem item) {
    final key = (type, item.id);
    if (!_mediaCache.containsKey(key) && _mediaCache.length >= 100) _mediaCache.remove(_mediaCache.keys.first);
    _mediaCache[key] = item;
  }

  Future<WatchHistoryEntry> _fromRow(Map<String, dynamic> row) async {
    final type = MediaType.values.firstWhere((type) => type.name == row['media_type'], orElse: () => MediaType.movie);
    final id = (row['media_id'] as num).toInt();
    var item = _mediaCache[(type, id)];
    if (item == null) {
      try {
        item = await _catalog.mediaItem(id, type);
        _cacheMedia(type, item);
      } catch (_) {
        item = MediaItem(id: id, title: '${type.name} $id', overview: '');
      }
    }
    final watchedAt = row['watched_at'] as String?;
    return WatchHistoryEntry(
      playback: PlaybackSession.fromJson({
        'provider': row['playback_provider'],
        'source': row['playback_source'],
        'language': row['audio_language'],
        'subtitles': row['subtitle_selection'],
        'subtitleDelaySeconds': row['subtitle_delay_seconds'],
        'positionSeconds': row['position_seconds'],
      }),
      type: type,
      season: (row['season'] as num?)?.toInt(),
      episode: (row['episode'] as num?)?.toInt(),
      watchedAt: watchedAt == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.tryParse(watchedAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      item: item,
    );
  }
}
