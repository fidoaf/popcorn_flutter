import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/routing/app_services.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/search/search.dart';

/// Resolves the playable [MediaSource] for a `/watch` route and records the
/// watch-history entry, then builds the platform player once via [builder].
///
/// When navigating within the app the full [item] is supplied. For a cold-start
/// deep link only the id/type are known, so the [MediaItem] is fetched to keep
/// the history entry rich; playback still works from the id alone if that fails.
class MediaPlaybackScaffold extends StatefulWidget {
  const MediaPlaybackScaffold({
    super.key,
    required this.id,
    required this.type,
    required this.services,
    required this.loadingBuilder,
    required this.builder,
    this.item,
    this.season,
    this.episode,
  });

  final int id;
  final MediaType type;
  final int? season;
  final int? episode;
  final MediaItem? item;
  final AppServices services;
  final WidgetBuilder loadingBuilder;
  final Widget Function(BuildContext context, MediaSource source, MediaItem item) builder;

  @override
  State<MediaPlaybackScaffold> createState() => _MediaPlaybackScaffoldState();
}

class _MediaPlaybackScaffoldState extends State<MediaPlaybackScaffold> {
  MediaSource? _source;
  MediaItem? _item;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _start(item);
    } else {
      widget.services.repository
          .mediaItem(widget.id, widget.type)
          .then((value) {
            if (mounted) setState(() => _start(value));
          })
          .catchError((Object _) {
            if (mounted) setState(() => _start(MediaItem(id: widget.id, title: '', overview: '')));
          });
    }
  }

  void _start(MediaItem item) {
    final type = widget.type;
    final resolvedSeason = type == MediaType.tv ? (widget.season ?? 1) : null;
    final resolvedEpisode = type == MediaType.tv ? (widget.episode ?? 1) : null;
    widget.services.historyController.record(item, type, season: resolvedSeason, episode: resolvedEpisode);
    _item = item;
    _source = widget.services.mediaSourceProvider.resolve(item, type, season: resolvedSeason, episode: resolvedEpisode);
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) return widget.loadingBuilder(context);
    return widget.builder(context, source, _item!);
  }
}
