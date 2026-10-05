import 'dart:async';

import 'package:flutter/foundation.dart';
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
  HomeFeedController({required MediaSearchRepository repository}) : _repository = repository {
    load();
  }

  final MediaSearchRepository _repository;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<({MediaItem item, MediaType type, MediaVideo video})> _trendingTrailers = const [];
  List<({MediaItem item, MediaType type, MediaVideo video})> get trendingTrailers => _trendingTrailers;

  bool _isLoading = true;

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
  MediaItem? get featured => _trendingMovies.isNotEmpty ? _trendingMovies.first : (_trendingTv.isNotEmpty ? _trendingTv.first : null);

  /// The [MediaType] of the [featured] title, so it can be opened/played.
  MediaType get featuredType => _trendingMovies.isNotEmpty ? MediaType.movie : MediaType.tv;

  /// Fetches both catalogues in parallel. Safe to call again to retry.
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _isLoading = true;
    _hasError = false;
    _trendingTrailers = const [];
    notifyListeners();

    try {
      final results = await Future.wait([_repository.trending(MediaType.movie), _repository.trending(MediaType.tv)]);
      if (_disposed || generation != _loadGeneration) return;
      _trendingMovies = results[0];
      _trendingTv = results[1];
      _hasError = _trendingMovies.isEmpty && _trendingTv.isEmpty;
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _trendingMovies = const [];
      _trendingTv = const [];
      _hasError = true;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
        if (!_hasError) unawaited(_loadTrailers(generation));
      }
    }
  }

  Future<void> _loadTrailers(int generation) async {
    final candidates = [
      for (final item in _trendingMovies.take(6)) (item: item, type: MediaType.movie),
      for (final item in _trendingTv.take(6)) (item: item, type: MediaType.tv),
    ];
    final results = await Future.wait(
      candidates.map((candidate) async {
        try {
          final videos = await _repository.videos(candidate.item.id, candidate.type);
          final trailers = videos.where((video) => video.type == 'Trailer' && video.key.isNotEmpty && video.embedUrl != null).toList();
          trailers.sort((first, second) => _publishedDate(second).compareTo(_publishedDate(first)));
          if (trailers.isEmpty) return null;
          return (item: candidate.item, type: candidate.type, video: trailers.first);
        } catch (_) {
          return null;
        }
      }),
    );
    if (_disposed || generation != _loadGeneration) return;
    final trailers = results.whereType<({MediaItem item, MediaType type, MediaVideo video})>().toList();
    trailers.sort((first, second) => _publishedDate(second.video).compareTo(_publishedDate(first.video)));
    _trendingTrailers = List.unmodifiable(trailers);
    notifyListeners();
  }

  static DateTime _publishedDate(MediaVideo video) => video.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
