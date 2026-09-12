import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Loads the trending movie and TV catalogues that drive the Prime Video-style
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
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final results = await Future.wait([_repository.trending(MediaType.movie), _repository.trending(MediaType.tv)]);
      _trendingMovies = results[0];
      _trendingTv = results[1];
      _hasError = _trendingMovies.isEmpty && _trendingTv.isEmpty;
    } catch (_) {
      _trendingMovies = const [];
      _trendingTv = const [];
      _hasError = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
