import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_subtitle.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Fluent (Windows) list of the user's "continue watching" history.
///
/// Selecting a row opens the details page ([onMediaSelected]); the trailing
/// play button resumes playback ([onMediaPlay]).
class FluentContinueWatchingView extends StatelessWidget {
  const FluentContinueWatchingView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay});

  final WatchHistoryController controller;

  final ValueChanged<WatchHistoryEntry>? onMediaSelected;
  final ValueChanged<WatchHistoryEntry>? onMediaPlay;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        padding: 16,
        leading: IconButton(icon: const Icon(FluentIcons.back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(WatchHistoryTranslations.pageTitle.trOf(context)),
      ),
      content: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final entries = controller.entries;
          if (entries.isEmpty) {
            return Center(child: Text(WatchHistoryTranslations.emptyList.trOf(context)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final item = entry.item;
              return ListTile.selectable(
                leading: _Poster(url: item.posterUrl),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(watchHistorySubtitle(entry), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMediaPlay != null) IconButton(icon: const Icon(FluentIcons.play_solid), onPressed: () => onMediaPlay!(entry)),
                    IconButton(icon: const Icon(FluentIcons.clear), onPressed: () => controller.remove(entry.type, item.id)),
                  ],
                ),
                selected: false,
                onSelectionChange: onMediaSelected == null ? null : (_) => onMediaSelected!(entry),
              );
            },
          );
        },
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 40;
  static const double _height = 60;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(context, FluentIcons.video);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(context, FluentIcons.error),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: FluentTheme.of(context).resources.subtleFillColorSecondary, borderRadius: BorderRadius.circular(4)),
      child: Icon(icon),
    );
  }
}
