import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/details/view/media_details_format.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
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
