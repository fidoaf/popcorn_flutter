import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/profile/domain/home_section.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/domain/media_video.dart';

/// Loads the trending movie and TV catalogues that drive the streaming-style
/// home screen (hero banner + browse carousels).
///
/// Depends only on the [MediaSearchRepository] abstraction, so it works with any
/// data source and is trivial to unit test.
class HomeFeedController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  HomeFeedController({
    required MediaSearchRepository repository,
    Set<HomeSection>? enabledSections,
  }) : _repository = repository,
       _enabledSections = enabledSections ?? HomeSection.values.toSet(),
       _isLoading = enabledSections == null || enabledSections.isNotEmpty {
    load();
  }

  final MediaSearchRepository _repository;
  Set<HomeSection> _enabledSections;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<({MediaItem item, MediaType type, MediaVideo video})> _trendingTrailers =
      const [];
  List<({MediaItem item, MediaType type, MediaVideo video})>
  get trendingTrailers => _trendingTrailers;

  bool _isLoading;

  /// Whether the initial catalogue load is still in flight.
  bool get isLoading => _isLoading;

  bool _hasError = false;

  /// Whether the last load failed (both catalogues are empty).
  bool get hasError => _hasError;

  List<MediaItem> _trendingMovies = const [];

  /// Trending movies for the current week.
  List<MediaItem> get trendingMovies => _trendingMovies;

  List<MediaItem> _trendingTv = const [];

  /// Trending TV series for the current week.
  List<MediaItem> get trendingTv => _trendingTv;

  /// The title showcased in the hero banner (the top trending movie, or the top
  /// trending series when no movies are available). `null` while empty.
  MediaItem? get featured => _trendingMovies.isNotEmpty
      ? _trendingMovies.first
      : (_trendingTv.isNotEmpty ? _trendingTv.first : null);

  /// The [MediaType] of the [featured] title, so it can be opened/played.
  MediaType get featuredType =>
      _trendingMovies.isNotEmpty ? MediaType.movie : MediaType.tv;

  /// Updates which catalogues and trailers are needed for the active profile.
  Future<void> setEnabledSections(Iterable<HomeSection> sections) async {
    final nextSections = sections.toSet();
    if (setEquals(_enabledSections, nextSections)) return;
    _enabledSections = nextSections;
    await load();
  }

  /// Fetches only the catalogues required by the active profile. Safe to call
  /// again to retry.
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final loadMovies =
        _enabledSections.contains(HomeSection.movies) ||
        _enabledSections.contains(HomeSection.trailers);
    final loadTv =
        _enabledSections.contains(HomeSection.tvSeries) ||
        _enabledSections.contains(HomeSection.trailers);
    _hasError = false;
    _trendingTrailers = const [];
    if (!loadMovies) _trendingMovies = const [];
    if (!loadTv) _trendingTv = const [];
    if (!loadMovies && !loadTv) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final results = <MediaType, List<MediaItem>>{};
      await Future.wait([
        if (loadMovies)
          _repository
              .trending(MediaType.movie)
              .then((items) => results[MediaType.movie] = items),
        if (loadTv)
          _repository
              .trending(MediaType.tv)
              .then((items) => results[MediaType.tv] = items),
      ]);
      if (_disposed || generation != _loadGeneration) return;
      _trendingMovies = results[MediaType.movie] ?? const [];
      _trendingTv = results[MediaType.tv] ?? const [];
      _hasError =
          (loadMovies || loadTv) &&
          _trendingMovies.isEmpty &&
          _trendingTv.isEmpty;
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _trendingMovies = const [];
      _trendingTv = const [];
      _hasError = true;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
        if (_enabledSections.contains(HomeSection.trailers) && !_hasError)
          unawaited(_loadTrailers(generation));
      }
    }
  }

  Future<void> _loadTrailers(int generation) async {
    final candidates = [
      for (final item in _trendingMovies.take(6))
        (item: item, type: MediaType.movie),
      for (final item in _trendingTv.take(6)) (item: item, type: MediaType.tv),
    ];
    final results = await Future.wait(
      candidates.map((candidate) async {
        try {
          final videos = await _repository.videos(
            candidate.item.id,
            candidate.type,
          );
          final trailers = videos
              .where(
                (video) =>
                    video.type == 'Trailer' &&
                    video.key.isNotEmpty &&
                    video.embedUrl != null,
              )
              .toList();
          trailers.sort(
            (first, second) =>
                _publishedDate(second).compareTo(_publishedDate(first)),
          );
          if (trailers.isEmpty) return null;
          return (
            item: candidate.item,
            type: candidate.type,
            video: trailers.first,
          );
        } catch (_) {
          return null;
        }
      }),
    );
    if (_disposed || generation != _loadGeneration) return;
    final trailers = results
        .whereType<({MediaItem item, MediaType type, MediaVideo video})>()
        .toList();
    trailers.sort(
      (first, second) =>
          _publishedDate(second.video).compareTo(_publishedDate(first.video)),
    );
    _trendingTrailers = List.unmodifiable(trailers);
    notifyListeners();
  }

  static DateTime _publishedDate(MediaVideo video) =>
      video.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
