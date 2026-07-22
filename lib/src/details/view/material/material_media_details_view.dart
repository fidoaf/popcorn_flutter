import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/media_details_format.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Material (Android / web) details page for a single [MediaItem].
///
/// Shows the poster, title, release year, rating and overview along with a
/// prominent play button that launches the player via [onPlay].
class MaterialMediaDetailsView extends StatelessWidget {
  const MaterialMediaDetailsView({super.key, required this.item, this.details, this.videos, this.onPlay, this.onVideoPlay, this.autofocusPlay = false});

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

  /// Autofocus the play button so a D-pad/remote has an initial focus target.
  final bool autofocusPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;
    final overview = item.overview.trim();

    return ListView(
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
                  Text(item.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (year != null) ...[Text('$year', style: theme.textTheme.titleMedium), const SizedBox(width: 12)],
                      if (rating != null) ...[
                        const Icon(Icons.star, size: 18),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: theme.textTheme.titleMedium),
                      ],
                    ],
                  ),
                  _MetadataLine(details: details),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (onPlay != null)
          FilledButton.icon(
            autofocus: autofocusPlay,
            onPressed: () => onPlay!(item),
            icon: const Icon(Icons.play_arrow),
            label: Text(DetailsTranslations.play.trOf(context)),
          ),
        const SizedBox(height: 24),
        Text(DetailsTranslations.overview.trOf(context), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(overview.isEmpty ? DetailsTranslations.noOverview.trOf(context) : overview, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        _VideosSection(videos: videos, onVideoPlay: onVideoPlay),
      ],
    );
  }
}

/// Renders the runtime (movies) or season/episode counts (TV series) once the
/// [details] future resolves. Shows nothing while loading or on failure.
class _MetadataLine extends StatelessWidget {
  const _MetadataLine({this.details});

  final Future<MediaDetails>? details;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return FutureBuilder<MediaDetails>(
      future: details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final text = formatMediaDetails(context, data);
        if (text == null) return const SizedBox.shrink();
        final icon = data.runtime != null ? Icons.schedule : Icons.tv;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(text, style: theme.textTheme.titleMedium),
            ],
          ),
        );
      },
    );
  }
}

class _VideosSection extends StatelessWidget {
  const _VideosSection({this.videos, this.onVideoPlay});

  final Future<List<MediaVideo>>? videos;
  final ValueChanged<MediaVideo>? onVideoPlay;

  @override
  Widget build(BuildContext context) {
    if (videos == null) return const SizedBox.shrink();
    return FutureBuilder<List<MediaVideo>>(
      future: videos,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DetailsTranslations.videos.trOf(context), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items
                .where((v) => v.embedUrl != null)
                .map(
                  (video) => ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(video.type),
                    onTap: onVideoPlay == null ? null : () => onVideoPlay!(video),
                  ),
                ),
          ],
        );
      },
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
      return _placeholder(context, Icons.movie_outlined);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 40),
    );
  }
}
