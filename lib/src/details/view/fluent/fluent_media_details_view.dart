import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/seasons_sheet.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/fluent/fluent_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Fluent (Windows) details page for a single [MediaItem].
///
/// Shows the poster, title, release year, rating and overview along with a
/// prominent play button that launches the player via [onPlay].
class FluentMediaDetailsView extends StatelessWidget {
  const FluentMediaDetailsView({
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
                      builder: (context, text, data) {
                        final isRuntime = data.runtime != null;
                        final icon = isRuntime ? FluentIcons.clock : FluentIcons.t_v_monitor;
                        final hasSeasons = data.seasons.isNotEmpty;
                        final row = Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(icon),
                              const SizedBox(width: 6),
                              Flexible(child: Text(text, style: typography.subtitle)),
                              if (hasSeasons) ...[const SizedBox(width: 4), const Icon(FluentIcons.chevron_right)],
                            ],
                          ),
                        );
                        if (!hasSeasons) return row;
                        return HoverButton(onPressed: () => _showSeasonsSheet(context, data.seasons), builder: (context, states) => row);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (onPlay != null || (favoritesController != null && mediaType != null))
                      Row(
                        children: [
                          if (onPlay != null)
                            FilledButton(
                              onPressed: () => onPlay!(item),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [const Icon(FluentIcons.play_solid), const SizedBox(width: 8), Text(DetailsTranslations.play.trOf(context))],
                              ),
                            ),
                          if (favoritesController != null && mediaType != null) ...[
                            const SizedBox(width: 8),
                            FluentFavoriteButton(
                              controller: favoritesController!,
                              favorite: FavoriteMedia(item: item, type: mediaType!),
                              iconSize: 22,
                            ),
                          ],
                        ],
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
          CreditsBuilder(
            details: details,
            builder: (context, director, cast) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (director != null) ...[
                    Text(DetailsTranslations.director.trOf(context), style: typography.subtitle),
                    const SizedBox(height: 8),
                    Text(director, style: typography.body),
                  ],
                  if (director != null && cast != null) const SizedBox(height: 16),
                  if (cast != null) ...[
                    Text(DetailsTranslations.cast.trOf(context), style: typography.subtitle),
                    const SizedBox(height: 8),
                    Text(cast, style: typography.body),
                  ],
                ],
              ),
            ),
          ),
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

  void _showSeasonsSheet(BuildContext context, List<MediaSeason> seasons) {
    final theme = FluentTheme.of(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: DetailsTranslations.seasonsTitle.trOf(context),
      barrierColor: const Color(0x8A000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: theme.resources.solidBackgroundFillColorBase,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SeasonsSheetContent(
            seasons: seasons,
            titleStyle: theme.typography.subtitle,
            subtitleColor: theme.resources.textFillColorSecondary,
            episodesLoader: episodesLoader,
            onPlayEpisode: onPlayEpisode,
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
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
