import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';

/// Formats the extra metadata shown on the details page: the movie [runtime]
/// (e.g. `2h 16m`) or the TV series season/episode counts
/// (e.g. `3 seasons · 24 episodes`).
///
/// Returns `null` when there is nothing meaningful to display.
String? formatMediaDetails(BuildContext context, MediaDetails details) {
  final runtime = details.runtime;
  if (runtime != null && runtime > Duration.zero) {
    final hours = runtime.inHours;
    final minutes = runtime.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  final parts = <String>[];
  final seasons = details.numberOfSeasons;
  if (seasons != null && seasons > 0) {
    final label = (seasons == 1 ? DetailsTranslations.season : DetailsTranslations.seasons).trOf(context);
    parts.add('$seasons $label');
  }
  final episodes = details.numberOfEpisodes;
  if (episodes != null && episodes > 0) {
    final label = (episodes == 1 ? DetailsTranslations.episode : DetailsTranslations.episodes).trOf(context);
    parts.add('$episodes $label');
  }

  return parts.isEmpty ? null : parts.join(' \u00b7 ');
}
