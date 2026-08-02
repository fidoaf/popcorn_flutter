import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Builds the subtitle line for a history entry: `S1 · E1 · year · overview`,
/// omitting any part that is unavailable. Shared across every toolkit's
/// "continue watching" view so the formatting stays consistent.
String watchHistorySubtitle(WatchHistoryEntry entry) {
  final parts = <String>[];
  if (entry.type == MediaType.tv && entry.season != null && entry.episode != null) {
    parts.add('S${entry.season} \u00b7 E${entry.episode}');
  }
  final year = entry.item.releaseDate?.year;
  if (year != null) parts.add('$year');
  final overview = entry.item.overview.trim();
  if (overview.isNotEmpty) parts.add(overview);
  return parts.join(' \u00b7 ');
}
