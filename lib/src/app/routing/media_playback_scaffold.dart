import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/app/routing/app_services.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session_scope.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/player/view/player_close_button.dart';
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
  final Widget Function(BuildContext context, MediaSource source, MediaItem item, ValueChanged<Uri> onUrlChanged) builder;

  @override
  State<MediaPlaybackScaffold> createState() => _MediaPlaybackScaffoldState();
}

class _MediaPlaybackScaffoldState extends State<MediaPlaybackScaffold> {
  MediaSource? _source;
  MediaItem? _item;
  int? _season;
  int? _episode;
  PlaybackSession _initialSession = const PlaybackSession();
  String? _profileId;
  String? _historySaveError;

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
            if (mounted) _start(value);
          })
          .catchError((Object _) {
            if (mounted) _start(MediaItem(id: widget.id, title: '', overview: ''));
          });
    }
  }

  Future<void> _start(MediaItem item) async {
    final history = widget.services.historyController;
    try {
      await widget.services.profileController.reload();
      await history.ready;
      await history.reload();
    } catch (error) {
      debugPrint('Unable to load playback history: $error');
    }
    if (!mounted) return;
    _profileId = widget.services.profileController.activeProfileId;
    final type = widget.type;
    final previous = history.entries.where((entry) => entry.matches(type, item.id)).firstOrNull;
    final resolvedSeason = type == MediaType.tv ? (widget.season ?? previous?.season ?? 1) : null;
    final resolvedEpisode = type == MediaType.tv ? (widget.episode ?? previous?.episode ?? 1) : null;
    final sameEpisode = previous?.season == resolvedSeason && previous?.episode == resolvedEpisode;
    _initialSession = sameEpisode ? previous?.playback ?? const PlaybackSession() : const PlaybackSession();
    _season = resolvedSeason;
    _episode = resolvedEpisode;
    _item = item;
    final resolved = widget.services.mediaSourceProvider.resolve(item, type, season: resolvedSeason, episode: resolvedEpisode);
    final query = Map<String, String>.of(resolved.url.queryParameters);
    if (_initialSession.language != null && query.containsKey('lang')) query['lang'] = _initialSession.language!;
    if (_initialSession.subtitles != null && query.containsKey('sub')) query['sub'] = _initialSession.subtitles!.isEmpty ? '0' : '1';
    if (resolved.url.path == '/player') {
      if (_initialSession.provider != null) query['provider'] = _initialSession.provider!;
      query['resume'] = _initialSession.positionSeconds.toString();
      if (_initialSession.source != null) query['resumeSource'] = _initialSession.source!;
      if (_initialSession.subtitles != null) query['resumeSubtitles'] = _initialSession.subtitles!;
      if (kIsWeb) query['parentOrigin'] = Uri.base.origin;
      final title = item.title.trim();
      if (title.isNotEmpty) query['title'] = title;
      final year = item.releaseDate?.year;
      if (year != null) query['year'] = year.toString();
    }
    setState(() {
      _source = MediaSource(
        url: resolved.url.replace(queryParameters: query),
        method: resolved.method,
        headers: resolved.headers,
        cookies: resolved.cookies,
        body: resolved.body,
        data: resolved.data,
        sandbox: resolved.sandbox,
      );
    });
    // Defer recording so the controller's notifyListeners never fires while an
    // ancestor is still building (initState runs mid-build).
    _record(_initialSession);
  }

  void _record(PlaybackSession playback) {
    final item = _item;
    if (item == null) return;
    if (_profileId != widget.services.profileController.activeProfileId) {
      if (kDebugMode) debugPrint('[WatchHistory] Ignored playback event because the active profile changed');
      return;
    }
    final season = _season;
    final episode = _episode;
    void save() {
      if (_profileId != widget.services.profileController.activeProfileId) return;
      widget.services.historyController
          .record(item, widget.type, season: season, episode: episode, playback: playback)
          .then((_) {
            if (kDebugMode) debugPrint('[WatchHistory] Saved ${widget.type.name} ${item.id} at ${playback.positionSeconds}s');
            if (mounted && _historySaveError != null) setState(() => _historySaveError = null);
          })
          .catchError((Object error) {
            debugPrint('Unable to save playback history: $error');
            if (mounted) setState(() => _historySaveError = 'Watch history could not be saved: $error');
          });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => save());
    } else {
      save();
    }
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
      final expected = widget.services.mediaSourceProvider.resolve(item, MediaType.tv, season: nextSeason, episode: nextEpisode);
      if (!_matchesSource(url, expected.url)) continue;
      _season = nextSeason;
      _episode = nextEpisode;
      setState(() => _initialSession = const PlaybackSession());
      _record(_initialSession);
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

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) return widget.loadingBuilder(context);
    return PlaybackSessionScope(
      initial: _initialSession,
      onChanged: (session) {
        if (identical(source, _source)) _record(session);
      },
      mediaId: widget.id,
      mediaType: widget.type.name,
      season: _season,
      episode: _episode,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: ObjectKey(source),
            child: widget.builder(context, source, _item!, (url) {
              if (identical(source, _source)) _onUrlChanged(url);
            }),
          ),
          if (source.url.path == '/player')
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: PlayerCloseButton(
                    onClose: () {
                      final router = GoRouter.of(context);
                      if (router.canPop()) {
                        router.pop();
                      } else {
                        router.go(AppRoutes.details(widget.type, widget.id), extra: _item);
                      }
                    },
                  ),
                ),
              ),
            ),
          if (_historySaveError != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF9B1C20),
                child: Text(_historySaveError!, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}
