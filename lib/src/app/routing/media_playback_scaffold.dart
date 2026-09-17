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
    this.provider,
  });

  final int id;
  final MediaType type;
  final int? season;
  final int? episode;
  final MediaItem? item;

  /// Optional streaming backend name; when it matches one of the configured
  /// providers that backend is used, otherwise the active provider is kept.
  final String? provider;
  final AppServices services;
  final WidgetBuilder loadingBuilder;
  final Widget Function(BuildContext context, MediaSource source, MediaItem item, ValueChanged<Uri> onUrlChanged) builder;

  @override
  State<MediaPlaybackScaffold> createState() => _MediaPlaybackScaffoldState();
}

class _MediaPlaybackScaffoldState extends State<MediaPlaybackScaffold> {
  MediaSource? _source;
  MediaItem? _item;
  int? _season;
  int? _episode;

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
    _season = resolvedSeason;
    _episode = resolvedEpisode;
    widget.services.historyController.record(item, type, season: resolvedSeason, episode: resolvedEpisode);
    _item = item;
    _source = _provider().resolve(item, type, season: resolvedSeason, episode: resolvedEpisode);
  }

  /// Handles a navigation reported by the player. For TV series it checks
  /// whether [url] corresponds to the next episode (the next episode of the
  /// current season, or the first episode of the next season) and, if so,
  /// records that episode in the watch history and advances the tracked
  /// position so a subsequent advance is detected relative to it.
  void _onUrlChanged(Uri url) {
    final item = _item;
    final season = _season;
    final episode = _episode;
    if (item == null || widget.type != MediaType.tv || season == null || episode == null) return;

    // The next episode of the current season, or the first episode of the next
    // season (covering an end-of-season roll-over).
    final candidates = <(int, int)>[(season, episode + 1), (season + 1, 1)];
    for (final (nextSeason, nextEpisode) in candidates) {
      final expected = _provider().resolve(item, MediaType.tv, season: nextSeason, episode: nextEpisode);
      if (!_matchesSource(url, expected.url)) continue;
      _season = nextSeason;
      _episode = nextEpisode;
      widget.services.historyController.record(item, MediaType.tv, season: nextSeason, episode: nextEpisode);
      return;
    }
  }

  /// Whether the player-reported [url] points at the [expected] episode source,
  /// matching on host and path and requiring every query parameter of the
  /// expected source (e.g. `season`/`episode`) to be present with the same value.
  static bool _matchesSource(Uri url, Uri expected) {
    if (url.host != expected.host || url.path != expected.path) return false;
    for (final entry in expected.queryParameters.entries) {
      if (url.queryParameters[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// The provider selected via [MediaPlaybackScaffold.provider] when it matches
  /// a configured backend, otherwise the active provider.
  MediaSourceProvider _provider() {
    final name = widget.provider;
    final configurable = widget.services.mediaSourceProvider;
    if (name == null || name.isEmpty) return configurable;
    for (final provider in configurable.providers) {
      if (provider.name == name) return provider;
    }
    return configurable;
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) return widget.loadingBuilder(context);
    return widget.builder(context, source, _item!, _onUrlChanged);
  }
}
