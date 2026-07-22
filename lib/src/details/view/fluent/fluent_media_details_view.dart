import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Fluent (Windows) details page for a single [MediaItem].
///
/// Shows the poster, title, release year, rating and overview along with a
/// prominent play button that launches the player via [onPlay].
class FluentMediaDetailsView extends StatelessWidget {
  const FluentMediaDetailsView({super.key, required this.item, this.details, this.videos, this.onPlay, this.onVideoPlay});

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
    final typography = FluentTheme.of(context).typography;
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;
    final overview = item.overview.trim();

    return ScaffoldPage(
      header: PageHeader(
        padding: 16,
        leading: IconButton(icon: const Icon(FluentIcons.back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(item.title),
      ),
      content: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Poster(url: item.posterUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (year != null) ...[Text('$year', style: typography.subtitle), const SizedBox(width: 12)],
                        if (rating != null) ...[
                          const Icon(FluentIcons.favorite_star_fill),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: typography.subtitle),
                        ],
                      ],
                    ),
                    MetadataLineBuilder(
                      details: details,
                      builder: (context, text, isRuntime) {
                        final icon = isRuntime ? FluentIcons.clock : FluentIcons.t_v_monitor;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(icon),
                              const SizedBox(width: 6),
                              Text(text, style: typography.subtitle),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (onPlay != null)
                      FilledButton(
                        onPressed: () => onPlay!(item),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [const Icon(FluentIcons.play_solid), const SizedBox(width: 8), Text(DetailsTranslations.play.trOf(context))],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(DetailsTranslations.overview.trOf(context), style: typography.subtitle),
          const SizedBox(height: 8),
          Text(overview.isEmpty ? DetailsTranslations.noOverview.trOf(context) : overview, style: typography.body),
          const SizedBox(height: 24),
          VideosListBuilder(
            videos: videos,
            headerBuilder: (context) => Text(DetailsTranslations.videos.trOf(context), style: typography.subtitle),
            tileBuilder: (context, video) => ListTile.selectable(
              leading: const Icon(FluentIcons.play),
              title: Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(video.type),
              selected: false,
              onSelectionChange: onVideoPlay == null ? null : (_) => onVideoPlay!(video),
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.url});

  final Uri? url;

  static const double _width = 120;
  static const double _height = 180;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return _placeholder(context, FluentIcons.video);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
      decoration: BoxDecoration(color: FluentTheme.of(context).resources.subtleFillColorSecondary, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 40),
    );
  }
}
