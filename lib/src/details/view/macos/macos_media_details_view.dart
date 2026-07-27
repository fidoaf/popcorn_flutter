import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/seasons_sheet.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/view/favorites_controller.dart';
import 'package:popcorn_flutter/src/favorites/view/macos/macos_favorite_button.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// macOS-native details page for a single [MediaItem].
///
/// Uses `macos_ui` widgets for a proper desktop macOS look. Shows the poster,
/// title, release year, rating and overview along with a prominent play button.
class MacosMediaDetailsView extends StatelessWidget {
  const MacosMediaDetailsView({
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
                    builder: (context, text, data) {
                      final isRuntime = data.runtime != null;
                      final icon = isRuntime ? CupertinoIcons.clock : CupertinoIcons.tv;
                      final hasSeasons = data.seasons.isNotEmpty;
                      final row = Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            MacosIcon(icon, size: 16, color: MacosColors.systemGrayColor),
                            const SizedBox(width: 6),
                            Flexible(child: Text(text, style: typography.headline)),
                            if (hasSeasons) ...[
                              const SizedBox(width: 2),
                              const MacosIcon(CupertinoIcons.chevron_right, size: 14, color: MacosColors.systemGrayColor),
                            ],
                          ],
                        ),
                      );
                      if (!hasSeasons) return row;
                      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _showSeasonsSheet(context, data.seasons), child: row);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (onPlay != null || (favoritesController != null && mediaType != null))
                    Row(
                      children: [
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
                        if (favoritesController != null && mediaType != null) ...[
                          const SizedBox(width: 8),
                          MacosFavoriteButton(
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

  void _showSeasonsSheet(BuildContext context, List<MediaSeason> seasons) {
    final typography = MacosTheme.of(context).typography;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        color: MacosTheme.of(context).canvasColor,
        child: SeasonsSheetContent(seasons: seasons, titleStyle: typography.title1, subtitleColor: MacosColors.systemGrayColor, episodesLoader: episodesLoader),
      ),
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
