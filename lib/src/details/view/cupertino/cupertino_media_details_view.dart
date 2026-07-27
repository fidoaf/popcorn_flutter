import 'package:flutter/cupertino.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/seasons_sheet.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/cupertino/cupertino_favorite_button.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Cupertino (macOS) details page for a single [MediaItem].
///
/// Shows the poster, title, release year, rating and overview along with a
/// prominent play button that launches the player via [onPlay].
class CupertinoMediaDetailsView extends StatelessWidget {
  const CupertinoMediaDetailsView({
    super.key,
    required this.item,
    this.details,
    this.videos,
    this.onPlay,
    this.onVideoPlay,
    this.episodesLoader,
    this.favoritesController,
    this.mediaType,
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

  /// Drives the favorite toggle. When `null` (or [mediaType] is `null`), no
  /// favorite button is shown.
  final FavoritesController? favoritesController;

  /// The [MediaType] of [item], needed to persist the favorite.
  final MediaType? mediaType;

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
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
                  Text(item.title, style: textTheme.navLargeTitleTextStyle),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (year != null) ...[Text('$year', style: textTheme.navTitleTextStyle), const SizedBox(width: 12)],
                      if (rating != null) ...[
                        const Icon(CupertinoIcons.star_fill, size: 16, color: CupertinoColors.systemYellow),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: textTheme.navTitleTextStyle),
                      ],
                    ],
                  ),
                  MetadataLineBuilder(
                    details: details,
                    builder: (context, text, data) {
                      final isRuntime = data.runtime != null;
                      final icon = isRuntime ? CupertinoIcons.clock : CupertinoIcons.tv;
                      final hasSeasons = data.seasons.isNotEmpty;
                      final row = Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: CupertinoColors.secondaryLabel),
                            const SizedBox(width: 4),
                            Flexible(child: Text(text, style: textTheme.textStyle)),
                            if (hasSeasons) ...[
                              const SizedBox(width: 2),
                              const Icon(CupertinoIcons.chevron_right, size: 14, color: CupertinoColors.secondaryLabel),
                            ],
                          ],
                        ),
                      );
                      if (!hasSeasons) return row;
                      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _showSeasonsSheet(context, data.seasons), child: row);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (onPlay != null || (favoritesController != null && mediaType != null))
          Row(
            children: [
              if (onPlay != null)
                CupertinoButton.filled(
                  onPressed: () => onPlay!(item),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [const Icon(CupertinoIcons.play_fill, size: 18), const SizedBox(width: 6), Text(DetailsTranslations.play.trOf(context))],
                  ),
                ),
              if (favoritesController != null && mediaType != null) ...[
                const SizedBox(width: 8),
                CupertinoFavoriteButton(controller: favoritesController!, favorite: FavoriteMedia(item: item, type: mediaType!), iconSize: 28),
              ],
            ],
          ),
        const SizedBox(height: 24),
        Text(DetailsTranslations.overview.trOf(context), style: textTheme.navTitleTextStyle),
        const SizedBox(height: 8),
        Text(overview.isEmpty ? DetailsTranslations.noOverview.trOf(context) : overview, style: textTheme.textStyle),
        const SizedBox(height: 24),
        VideosListBuilder(
          videos: videos,
          headerBuilder: (context) => Text(DetailsTranslations.videos.trOf(context), style: textTheme.navTitleTextStyle),
          tileBuilder: (context, video) => GestureDetector(
            onTap: onVideoPlay == null ? null : () => onVideoPlay!(video),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.play_circle, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.textStyle),
                        Text(video.type, style: textTheme.tabLabelTextStyle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSeasonsSheet(BuildContext context, List<MediaSeason> seasons) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SeasonsSheetContent(
          seasons: seasons,
          titleStyle: textTheme.navTitleTextStyle,
          subtitleColor: CupertinoColors.secondaryLabel.resolveFrom(context),
          episodesLoader: episodesLoader,
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
      decoration: BoxDecoration(color: CupertinoColors.systemGrey5, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 40, color: CupertinoColors.systemGrey),
    );
  }
}
