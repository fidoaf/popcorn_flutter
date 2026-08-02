import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/history/domain/watch_history_entry.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_controller.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_subtitle.dart';
import 'package:popcorn_flutter/src/history/view/watch_history_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// macOS-native list of the user's "continue watching" history.
///
/// Tapping a row opens the details page ([onMediaSelected]); the trailing play
/// button resumes playback ([onMediaPlay]).
class MacosContinueWatchingView extends StatelessWidget {
  const MacosContinueWatchingView({super.key, required this.controller, this.onMediaSelected, this.onMediaPlay});

  final WatchHistoryController controller;

  final ValueChanged<WatchHistoryEntry>? onMediaSelected;
  final ValueChanged<WatchHistoryEntry>? onMediaPlay;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.entries;
        if (entries.isEmpty) {
          return Center(child: Text(WatchHistoryTranslations.emptyList.trOf(context), style: typography.body));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final item = entry.item;
            return GestureDetector(
              onTap: onMediaSelected == null ? null : () => onMediaSelected!(entry),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _Poster(url: item.posterUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: typography.headline),
                          const SizedBox(height: 2),
                          Text(watchHistorySubtitle(entry), maxLines: 2, overflow: TextOverflow.ellipsis, style: typography.subheadline),
                        ],
                      ),
                    ),
                    if (onMediaPlay != null) MacosIconButton(icon: const MacosIcon(CupertinoIcons.play_arrow_solid), onPressed: () => onMediaPlay!(entry)),
                    MacosIconButton(icon: const MacosIcon(CupertinoIcons.clear), onPressed: () => controller.remove(entry.type, item.id)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 46;
  static const double _height = 69;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(CupertinoIcons.film);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url.toString(),
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _placeholder(CupertinoIcons.photo),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(color: MacosColors.systemGrayColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: MacosIcon(icon, color: MacosColors.systemGrayColor),
    );
  }
}
