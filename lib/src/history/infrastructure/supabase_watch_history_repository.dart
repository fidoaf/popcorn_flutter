import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_repository.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [WatchHistoryRepository] backed by the Supabase `watch_history` table, scoped
/// to the signed-in user's profile.
///
/// Returns an empty list when signed out. [save] replaces the profile's stored
/// history; entries are read back most-recently-watched first.
class SupabaseWatchHistoryRepository implements WatchHistoryRepository {
  SupabaseWatchHistoryRepository({required ProfileRepository profileRepository, SupabaseClient? client})
    : _profiles = profileRepository,
      _client = client ?? Supabase.instance.client;

  static const String _table = 'watch_history';

  final ProfileRepository _profiles;
  final SupabaseClient _client;

  @override
  Future<List<WatchHistoryEntry>> load() async {
    final profile = await _profiles.activeProfile();
    if (profile == null) return const [];
    final rows = await _client.from(_table).select().eq('profile_id', profile.id).order('watched_at', ascending: false);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(List<WatchHistoryEntry> entries) async {
    final profile = await _profiles.activeProfile();
    if (profile == null) return;
    await _client.from(_table).delete().eq('profile_id', profile.id);
    if (entries.isEmpty) return;
    final rows = entries.map((entry) => _toRow(entry, profile.id)).toList();
    await _client.from(_table).insert(rows);
  }

  Map<String, dynamic> _toRow(WatchHistoryEntry entry, String profileId) => {
    'profile_id': profileId,
    'media_type': entry.type.name,
    'media_id': entry.item.id,
    'title': entry.item.title,
    'overview': entry.item.overview,
    'poster_url': entry.item.posterUrl?.toString(),
    'release_date': entry.item.releaseDate?.toIso8601String(),
    'vote_average': entry.item.voteAverage,
    'season': entry.season,
    'episode': entry.episode,
    'watched_at': entry.watchedAt.toIso8601String(),
  };

  WatchHistoryEntry _fromRow(Map<String, dynamic> row) {
    final posterUrl = row['poster_url'] as String?;
    final releaseDate = row['release_date'] as String?;
    final watchedAt = row['watched_at'] as String?;
    return WatchHistoryEntry(
      type: MediaType.values.firstWhere((type) => type.name == row['media_type'], orElse: () => MediaType.movie),
      season: (row['season'] as num?)?.toInt(),
      episode: (row['episode'] as num?)?.toInt(),
      watchedAt: watchedAt == null ? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.tryParse(watchedAt) ?? DateTime.fromMillisecondsSinceEpoch(0),
      item: MediaItem(
        id: (row['media_id'] as num).toInt(),
        title: row['title'] as String? ?? '',
        overview: row['overview'] as String? ?? '',
        posterUrl: posterUrl == null ? null : Uri.tryParse(posterUrl),
        releaseDate: releaseDate == null ? null : DateTime.tryParse(releaseDate),
        voteAverage: (row['vote_average'] as num?)?.toDouble(),
      ),
    );
  }
}
