import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/profile/domain/profile_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [FavoritesRepository] backed by the Supabase `favorites` table, scoped to the
/// signed-in user's profile.
///
/// Returns an empty list when signed out. [save] replaces the profile's stored
/// set, preserving list order via the `position` column.
class SupabaseFavoritesRepository implements FavoritesRepository {
  SupabaseFavoritesRepository({required ProfileRepository profileRepository, SupabaseClient? client})
    : _profiles = profileRepository,
      _client = client ?? Supabase.instance.client;

  static const String _table = 'favorites';

  final ProfileRepository _profiles;
  final SupabaseClient _client;

  @override
  Future<List<FavoriteMedia>> load() async {
    final profile = await _profiles.activeProfile();
    if (profile == null) return const [];
    final rows = await _client.from(_table).select().eq('profile_id', profile.id).order('position');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(List<FavoriteMedia> favorites) async {
    final profile = await _profiles.activeProfile();
    if (profile == null) return;
    await _client.from(_table).delete().eq('profile_id', profile.id);
    if (favorites.isEmpty) return;
    final rows = [for (final (index, favorite) in favorites.indexed) _toRow(favorite, profile.id, index)];
    await _client.from(_table).insert(rows);
  }

  Map<String, dynamic> _toRow(FavoriteMedia favorite, String profileId, int position) => {
    'profile_id': profileId,
    'media_type': favorite.type.name,
    'media_id': favorite.item.id,
    'title': favorite.item.title,
    'overview': favorite.item.overview,
    'poster_url': favorite.item.posterUrl?.toString(),
    'release_date': favorite.item.releaseDate?.toIso8601String(),
    'vote_average': favorite.item.voteAverage,
    'position': position,
  };

  FavoriteMedia _fromRow(Map<String, dynamic> row) {
    final posterUrl = row['poster_url'] as String?;
    final releaseDate = row['release_date'] as String?;
    return FavoriteMedia(
      type: MediaType.values.firstWhere((type) => type.name == row['media_type'], orElse: () => MediaType.movie),
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
