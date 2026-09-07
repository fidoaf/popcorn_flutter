import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Resumes playback of [item] from a prior [season]/[episode] (both `null` for
/// movies). Shared by every toolkit's details view so the wiring stays uniform.
typedef ResumePlayCallback = void Function(MediaItem item, {int? season, int? episode});

/// The watch-history entry for [item] of [type], or `null` when there is no
/// history (so the details page keeps its fresh "Play" button).
WatchHistoryEntry? resumeEntryFor(WatchHistoryController? controller, MediaType? type, MediaItem item) {
  if (controller == null || type == null) return null;
  return controller.entries.firstWhereOrNull((entry) => entry.matches(type, item.id));
}

/// Whether [entry] can resume a specific TV episode via [ResumePlayCallback].
bool _canResumeEpisode(WatchHistoryEntry? entry) => entry != null && entry.type == MediaType.tv && entry.season != null && entry.episode != null;

/// Label for the details play button: "Play" with no history, otherwise
/// "Resume" — suffixed with "S{season} · E{episode}" for a resumable TV episode.
String detailsPlayLabel(BuildContext context, WatchHistoryEntry? entry) {
  if (entry == null) return DetailsTranslations.play.trOf(context);
  final resume = DetailsTranslations.resume.trOf(context);
  if (_canResumeEpisode(entry)) return '$resume S${entry.season} \u00b7 E${entry.episode}';
  return resume;
}

/// The `onPressed` for the details play button: resumes the last-watched
/// episode for TV history, otherwise starts playback from [onPlay].
VoidCallback? detailsPlayAction({
  required MediaItem item,
  required WatchHistoryEntry? entry,
  required ValueChanged<MediaItem>? onPlay,
  required ResumePlayCallback? onResume,
}) {
  if (onResume != null && _canResumeEpisode(entry)) {
    return () => onResume(item, season: entry!.season, episode: entry.episode);
  }
  if (onPlay != null) return () => onPlay(item);
  return null;
}
