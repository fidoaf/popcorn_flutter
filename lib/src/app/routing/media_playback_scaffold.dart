import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/app/routing/app_services.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session.dart';
import 'package:popcorn_flutter/src/player/domain/playback_session_scope.dart';
import 'package:popcorn_flutter/src/player/infrastructure/next_episode.dart';
import 'package:popcorn_flutter/src/player/player.dart';
import 'package:popcorn_flutter/src/player/view/player_close_button.dart';
import 'package:popcorn_flutter/src/player/view/player_overlay_layout.dart';
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
  (int, int)? _nextEpisode;
  int _generation = 0;
  Future<void> _lastSave = Future.value();
  bool _advancing = false;

  @override
  void didUpdateWidget(MediaPlaybackScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.type != widget.type || oldWidget.season != widget.season || oldWidget.episode != widget.episode) {
      _source = null;
      _nextEpisode = null;
      _loadItem();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  void _loadItem() {
    final generation = ++_generation;
    final item = widget.item;
    final id = widget.id;
    if (item != null) {
      _start(item);
    } else {
      widget.services.repository
          .mediaItem(id, widget.type)
          .then((value) {
            if (mounted && generation == _generation) _start(value);
          })
          .catchError((Object error) {
            debugPrint('Unable to load playback metadata: $error');
            if (mounted && generation == _generation) _start(MediaItem(id: id, title: '', overview: ''));
          });
    }
  }

  Future<void> _start(MediaItem item) async {
    final generation = ++_generation;
    final history = widget.services.historyController;
    try {
      await widget.services.profileController.reload();
      await history.ready;
      await history.reload();
    } catch (error) {
      debugPrint('Unable to load playback history: $error');
    }
    if (!mounted || generation != _generation) return;
    _profileId = widget.services.profileController.activeProfileId;
    final type = widget.type;
    final previous = history.entries.where((entry) => entry.matches(type, item.id)).firstOrNull;
    final resolvedSeason = type == MediaType.tv ? (widget.season ?? previous?.season ?? 1) : null;
    final resolvedEpisode = type == MediaType.tv ? (widget.episode ?? previous?.episode ?? 1) : null;
    final sameEpisode = previous?.season == resolvedSeason && previous?.episode == resolvedEpisode;
    final playback = previous?.playback;
    _initialSession = sameEpisode
        ? playback ?? const PlaybackSession()
        : PlaybackSession(
            provider: playback?.provider,
            source: playback?.source,
            language: playback?.language,
            subtitles: playback?.subtitles,
            subtitleDelaySeconds: playback?.subtitleDelaySeconds ?? 0,
          );
    _season = resolvedSeason;
    _episode = resolvedEpisode;
    _item = item;
    if (type == MediaType.tv) {
      (int, int)? next;
      try {
        next = await findNextEpisode(widget.services.repository, item.id, resolvedSeason!, resolvedEpisode!).timeout(const Duration(seconds: 10));
      } catch (error) {
        debugPrint('Unable to resolve next episode: $error');
      }
      if (!mounted || generation != _generation) return;
      _nextEpisode = next;
    }
    final resolved = widget.services.mediaSourceProvider.resolve(item, type, season: resolvedSeason, episode: resolvedEpisode);
    final query = Map<String, String>.of(resolved.url.queryParameters);
    if (_initialSession.language != null && query.containsKey('lang')) query['lang'] = _initialSession.language!;
    if (_initialSession.subtitles != null && query.containsKey('sub')) query['sub'] = _initialSession.subtitles!.isEmpty ? '0' : '1';
    if (resolved.url.path == '/player') {
      if (_initialSession.provider != null) query['provider'] = _initialSession.provider!;
      query['resume'] = _initialSession.positionSeconds.toString();
      if (_initialSession.source != null) query['resumeSource'] = _initialSession.source!;
      if (_initialSession.subtitles != null) query['resumeSubtitles'] = _initialSession.subtitles!;
      query['resumeSubtitleDelay'] = _initialSession.subtitleDelaySeconds.toString();
      if (kIsWeb) query['parentOrigin'] = Uri.base.origin;
      final title = item.title.trim();
      if (title.isNotEmpty) query['title'] = title;
      final year = item.releaseDate?.year;
      if (year != null) query['year'] = year.toString();
      final next = _nextEpisode;
      if (next != null) {
        query['nextSeason'] = '${next.$1}';
        query['nextEpisode'] = '${next.$2}';
      }
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
      _lastSave = widget.services.historyController
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
      onNextEpisode: _nextEpisode == null ? null : () => _advance(source),
      nextSeason: _nextEpisode?.$1,
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
                  padding: EdgeInsets.only(top: 12 + playerOverlayTopInset(context), right: 12),
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

  Future<void> _advance(MediaSource source) async {
    if (_advancing || !identical(source, _source) || _profileId != widget.services.profileController.activeProfileId) return;
    _advancing = true;
    await _lastSave;
    if (mounted && identical(source, _source) && _profileId == widget.services.profileController.activeProfileId) {
      final next = _nextEpisode!;
      setState(() => _source = null);
      Router.neglect(context, () {
        GoRouter.of(context).replace(
          AppRoutes.watch(widget.type, widget.id, season: next.$1, episode: next.$2),
          extra: _item,
        );
      });
    }
    _advancing = false;
  }
}
