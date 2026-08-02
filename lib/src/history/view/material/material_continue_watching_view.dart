import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_subtitle.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Material (Android / web) list of the user's "continue watching" history.
///
/// Rows behave like the search results page: tapping a row opens the details
/// page ([onMediaSelected]) while the trailing play button resumes playback
/// ([onMediaPlay]).
class MaterialContinueWatchingView extends StatelessWidget {
  const MaterialContinueWatchingView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay});

  final WatchHistoryController controller;

  /// Called when a row is tapped (opens the details page).
  final ValueChanged<WatchHistoryEntry>? onMediaSelected;

  /// Called when a row's play button is tapped (resumes playback).
  final ValueChanged<WatchHistoryEntry>? onMediaPlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.entries;
        if (entries.isEmpty) {
          return Center(child: Text(WatchHistoryTranslations.emptyList.trOf(context)));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final item = entry.item;
            return ListTile(
              leading: _Poster(url: item.posterUrl),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(watchHistorySubtitle(entry), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMediaPlay != null) IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => onMediaPlay!(entry)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: WatchHistoryTranslations.removeFromHistory.trOf(context),
                    onPressed: () => controller.remove(entry.type, item.id),
                  ),
                ],
              ),
              onTap: onMediaSelected == null ? null : () => onMediaSelected!(entry),
            );
          },
        );
      },
    );
  }
}

/// Material (Android / web) "continue watching" list poster thumbnail.
class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 46;
  static const double _height = 69;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(context, Icons.movie_outlined);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, Icons.broken_image_outlined),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
