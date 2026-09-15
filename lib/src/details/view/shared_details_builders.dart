import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/details/view/media_details_format.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Shared builder that resolves a [Future<MediaDetails>] and delegates
/// rendering to [builder] once data is available.
///
/// Hides itself when [details] is null, loading, or has no displayable text.
class MetadataLineBuilder extends StatelessWidget {
  const MetadataLineBuilder({super.key, this.details, required this.builder});

  final Future<MediaDetails>? details;

  /// Called with the formatted text and the resolved [MediaDetails] so callers
  /// can pick an icon (runtime vs. seasons) or wire up a per-season sheet.
  final Widget Function(BuildContext context, String text, MediaDetails data) builder;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SizedBox.shrink();
    return FutureBuilder<MediaDetails>(
      future: details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final text = formatMediaDetails(context, data);
        if (text == null) return const SizedBox.shrink();
        return builder(context, text, data);
      },
    );
  }
}

/// Shared builder that resolves a [Future<List<MediaVideo>>] and delegates
/// rendering of each video to [tileBuilder].
///
/// Hides itself when [videos] is null, loading, or the list is empty.
class VideosListBuilder extends StatelessWidget {
  const VideosListBuilder({super.key, this.videos, required this.headerBuilder, required this.tileBuilder});

  final Future<List<MediaVideo>>? videos;

  /// Builds the section header (e.g. "Videos" title).
  final WidgetBuilder headerBuilder;

  /// Builds a single video tile.
  final Widget Function(BuildContext context, MediaVideo video) tileBuilder;

  @override
  Widget build(BuildContext context) {
    if (videos == null) return const SizedBox.shrink();
    return FutureBuilder<List<MediaVideo>>(
      future: videos,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        final playable = items.where((v) => v.embedUrl != null).toList(growable: false);
        if (playable.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [headerBuilder(context), const SizedBox(height: 8), ...playable.map((video) => tileBuilder(context, video))],
        );
      },
    );
  }
}

/// Shared builder that resolves a [Future<MediaDetails>] and exposes the
/// director and formatted cast so each platform view can render them.
///
/// Hides itself when [details] is null, loading, or carries neither a director
/// nor any cast members.
class CreditsBuilder extends StatelessWidget {
  const CreditsBuilder({super.key, this.details, required this.builder});

  final Future<MediaDetails>? details;

  /// Called with the director (may be null) and the cast names joined into a
  /// single line (may be null when empty).
  final Widget Function(BuildContext context, String? director, String? cast) builder;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SizedBox.shrink();
    return FutureBuilder<MediaDetails>(
      future: details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final director = data.director;
        final cast = data.cast.isEmpty ? null : data.cast.join(', ');
        if (director == null && cast == null) return const SizedBox.shrink();
        return builder(context, director, cast);
      },
    );
  }
}

/// Shared builder that resolves a [Future<MediaDetails>] and exposes the
/// production status (in production, ended, canceled, …) so each platform view
/// can render its own badge.
///
/// Hides itself when [details] is null, loading, or the status carries no
/// useful signal (released, rumored or unknown).
class ProductionStatusBuilder extends StatelessWidget {
  const ProductionStatusBuilder({super.key, this.details, required this.builder});

  final Future<MediaDetails>? details;

  /// Called with the localized status label and its [ProductionStatusTone].
  final Widget Function(BuildContext context, String label, ProductionStatusTone tone) builder;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SizedBox.shrink();
    return FutureBuilder<MediaDetails>(
      future: details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final status = formatProductionStatus(context, data.status);
        if (status == null) return const SizedBox.shrink();
        return builder(context, status.label, status.tone);
      },
    );
  }
}

/// Shared builder that resolves a [Future<List<MediaItem>>] of related titles
/// and renders them as a horizontal poster carousel.
///
/// Hides itself when [related] is null, loading, failed, or the list is empty.
/// Tapping a poster invokes [onSelected] with the chosen [MediaItem].
class RelatedMediaBuilder extends StatelessWidget {
  const RelatedMediaBuilder({super.key, this.related, required this.headerBuilder, required this.onSelected});

  final Future<List<MediaItem>>? related;

  /// Builds the section header (e.g. "More like this" title).
  final WidgetBuilder headerBuilder;

  /// Called with the tapped related [MediaItem].
  final ValueChanged<MediaItem> onSelected;

  static const double _cardWidth = 120;
  static const double _cardHeight = 180;

  @override
  Widget build(BuildContext context) {
    if (related == null) return const SizedBox.shrink();
    return FutureBuilder<List<MediaItem>>(
      future: related,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerBuilder(context),
            const SizedBox(height: 8),
            SizedBox(
              height: _cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _RelatedCard(item: item, width: _cardWidth, height: _cardHeight, onTap: () => onSelected(item));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single tappable related-media poster used by [RelatedMediaBuilder].
///
/// Kept in `package:flutter/widgets.dart` so it renders identically under
/// Material, Fluent, Cupertino and macOS detail views.
class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.item, required this.width, required this.height, required this.onTap});

  final MediaItem item;
  final double width;
  final double height;
  final VoidCallback onTap;

  static const Color _placeholderColor = Color(0x33808080);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: item.posterUrl == null
              ? _placeholder()
              : Image.network(item.posterUrl.toString(), width: width, height: height, fit: BoxFit.cover, errorBuilder: (context, _, _) => _placeholder()),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: _placeholderColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
    );
  }
}
