import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// macOS-native details page for a single [MediaItem].
///
/// Uses `macos_ui` widgets for a proper desktop macOS look. Shows the poster,
/// title, release year, rating and overview along with a prominent play button.
class MacosMediaDetailsView extends StatelessWidget {
  const MacosMediaDetailsView({super.key, required this.item, this.details, this.videos, this.onPlay, this.onVideoPlay});

  final MediaItem item;

  /// Extended metadata (runtime for movies, seasons/episodes for TV series),
  /// loaded on demand. `null` when no extended metadata is available.
  final Future<MediaDetails>? details;

  /// Videos (trailers, teasers, etc.) for this item, loaded on demand.
  final Future<List<MediaVideo>>? videos;

  /// Called when the play button is tapped (launches the player).
  final ValueChanged<MediaItem>? onPlay;

  /// Called when a video tile is tapped (plays the video in-app).
  final ValueChanged<MediaVideo>? onVideoPlay;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;
    final overview = item.overview.trim();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Poster(url: item.posterUrl),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: typography.largeTitle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (year != null) ...[Text('$year', style: typography.headline), const SizedBox(width: 12)],
                      if (rating != null) ...[
                        const MacosIcon(CupertinoIcons.star_fill, size: 16, color: MacosColors.systemYellowColor),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: typography.headline),
                      ],
                    ],
                  ),
                  MetadataLineBuilder(
                    details: details,
                    builder: (context, text, isRuntime) {
                      final icon = isRuntime ? CupertinoIcons.clock : CupertinoIcons.tv;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            MacosIcon(icon, size: 16, color: MacosColors.systemGrayColor),
                            const SizedBox(width: 6),
                            Text(text, style: typography.headline),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (onPlay != null)
                    PushButton(
                      controlSize: ControlSize.large,
                      onPressed: () => onPlay!(item),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MacosIcon(CupertinoIcons.play_fill, size: 14, color: MacosColors.white),
                          const SizedBox(width: 6),
                          Text(DetailsTranslations.play.trOf(context)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(DetailsTranslations.overview.trOf(context), style: typography.headline),
        const SizedBox(height: 8),
        Text(overview.isEmpty ? DetailsTranslations.noOverview.trOf(context) : overview, style: typography.body),
        const SizedBox(height: 24),
        VideosListBuilder(
          videos: videos,
          headerBuilder: (context) => Text(DetailsTranslations.videos.trOf(context), style: typography.headline),
          tileBuilder: (context, video) => _VideoTile(video: video, onPlay: onVideoPlay),
        ),
      ],
    );
  }
}

class _VideoTile extends StatefulWidget {
  const _VideoTile({required this.video, this.onPlay});

  final MediaVideo video;
  final ValueChanged<MediaVideo>? onPlay;

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPlay == null ? null : () => widget.onPlay!(widget.video),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovering ? MacosTheme.of(context).primaryColor.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const MacosIcon(CupertinoIcons.play_circle, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: typography.body),
                    Text(widget.video.type, style: typography.subheadline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 140;
  static const double _height = 210;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(CupertinoIcons.film);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
      decoration: BoxDecoration(color: MacosColors.systemGrayColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: MacosIcon(icon, size: 40, color: MacosColors.systemGrayColor),
    );
  }
}
