import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/material/material_share_button.dart';
import 'package:popcorn_flutter/src/details/view/seasons_sheet.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/material/material_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Material (Android / web) details page for a single [MediaItem].
///
/// Shows the poster, title, release year, rating and overview along with a
/// prominent play button that launches the player via [onPlay].
class MaterialMediaDetailsView extends StatelessWidget {
  const MaterialMediaDetailsView({
    super.key,
    required this.item,
    this.details,
    this.videos,
    this.onPlay,
    this.onVideoPlay,
    this.episodesLoader,
    this.onPlayEpisode,
    this.favoritesController,
    this.mediaType,
    this.autofocusPlay = false,
  });
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

  /// Loads the episodes for a tapped season in the seasons sheet.
  final SeasonEpisodesLoader? episodesLoader;

  /// Called when an episode's play button is tapped (launches the player).
  final EpisodePlayCallback? onPlayEpisode;

  /// Drives the favorite toggle. When `null` (or [mediaType] is `null`), no
  /// favorite button is shown.
  final FavoritesController? favoritesController;

  /// The [MediaType] of [item], needed to persist the favorite.
  final MediaType? mediaType;

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
                      if (year != null) ...[
                        Text('$year', style: theme.textTheme.titleMedium),
                        const SizedBox(width: 12),
                      ] else ...[
                        Text(DetailsTranslations.tba.trOf(context), style: theme.textTheme.titleMedium),
                        const SizedBox(width: 12),
                      ],
                      if (rating != null) ...[
                        const Icon(Icons.star, size: 18),
                        const SizedBox(width: 4),
                        Text(context.formatDecimal(rating), style: theme.textTheme.titleMedium),
                      ],
                    ],
                  ),
                  MetadataLineBuilder(
                    details: details,
                    builder: (context, text, data) {
                      final isRuntime = data.runtime != null;
                      final icon = isRuntime ? Icons.schedule : Icons.tv;
                      final hasSeasons = data.seasons.isNotEmpty;
                      final row = Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(child: Text(text, style: theme.textTheme.titleMedium)),
                            if (hasSeasons) ...[const SizedBox(width: 4), Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant)],
                          ],
                        ),
                      );
                      if (!hasSeasons) return row;
                      return InkWell(borderRadius: BorderRadius.circular(8), onTap: () => _showSeasonsSheet(context, data.seasons), child: row);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if ((onPlay != null && item.isReleased) || mediaType != null)
          Row(
            children: [
              if (onPlay != null && item.isReleased)
                FilledButton.icon(
                  autofocus: autofocusPlay,
                  onPressed: () => onPlay!(item),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(DetailsTranslations.play.trOf(context)),
                ),
              if (favoritesController != null && mediaType != null) ...[
                const SizedBox(width: 8),
                MaterialFavoriteButton(
                  controller: favoritesController!,
                  favorite: FavoriteMedia(item: item, type: mediaType!),
                  iconSize: 28,
                ),
              ],
              if (mediaType != null) ...[const SizedBox(width: 8), MaterialShareButton(item: item, type: mediaType!, iconSize: 28)],
            ],
          ),
        const SizedBox(height: 24),
        Text(DetailsTranslations.overview.trOf(context), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(overview.isEmpty ? DetailsTranslations.noOverview.trOf(context) : overview, style: theme.textTheme.bodyMedium),
        CreditsBuilder(
          details: details,
          builder: (context, director, cast) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (director != null) ...[
                  Text(DetailsTranslations.director.trOf(context), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(director, style: theme.textTheme.bodyMedium),
                ],
                if (director != null && cast != null) const SizedBox(height: 16),
                if (cast != null) ...[
                  Text(DetailsTranslations.cast.trOf(context), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(cast, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        VideosListBuilder(
          videos: videos,
          headerBuilder: (context) => Text(DetailsTranslations.videos.trOf(context), style: theme.textTheme.titleMedium),
          tileBuilder: (context, video) => ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(video.type),
            onTap: onVideoPlay == null ? null : () => onVideoPlay!(video),
          ),
        ),
      ],
    );
  }

  void _showSeasonsSheet(BuildContext context, List<MediaSeason> seasons) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SeasonsSheetContent(
          seasons: seasons,
          titleStyle: theme.textTheme.titleLarge,
          subtitleColor: theme.colorScheme.onSurfaceVariant,
          episodesLoader: episodesLoader,
          onPlayEpisode: onPlayEpisode,
        ),
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
