import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/media_search_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';

/// Drives movie and TV series searches and exposes the resulting [MediaSearchState].
///
/// Depends only on the [MediaSearchRepository] abstraction, so it works with
/// any data source and is trivial to unit test.
class MediaSearchController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  MediaSearchController({required MediaSearchRepository repository}) : _repository = repository {
    _loadTrending();
  }

  final MediaSearchRepository _repository;

  MediaSearchState _state = const MediaSearchIdle();
  MediaSearchState get state => _state;

  MediaType _mediaType = MediaType.movie;

  /// The kind of catalogue entry the next search will target.
  MediaType get mediaType => _mediaType;

  // Remembers the last query so a media type change can re-run it.
  String _lastQuery = '';

  // Guards against out-of-order responses when searches are issued rapidly.
  int _latestRequest = 0;

  // Cached trending items so returning to idle can restore them.
  List<MediaItem> _trendingItems = const [];

  /// Switches the searched catalogue and re-runs the current query, if any.
  void setMediaType(MediaType mediaType) {
    if (_mediaType == mediaType) return;
    _mediaType = mediaType;
    if (_lastQuery.isNotEmpty) {
      search(_lastQuery);
    } else {
      _loadTrending();
    }
  }

  Future<void> _loadTrending() async {
    _trendingItems = const [];
    _setState(const MediaSearchIdle());
    try {
      final items = await _repository.trending(_mediaType);
      _trendingItems = items;
      if (_state is MediaSearchIdle) {
        _setState(MediaSearchIdle(trendingItems: _trendingItems));
      }
    } catch (_) {
      // Trending is not critical – keep the idle state without items.
    }
  }

  Future<void> search(String query) async {
    final trimmedQuery = query.trim();
    _lastQuery = trimmedQuery;
    if (trimmedQuery.isEmpty) {
      clear();
      return;
    }

    final requestId = ++_latestRequest;
    _setState(const MediaSearchLoading());

    try {
      final items = await _repository.search(trimmedQuery, _mediaType);
      if (requestId != _latestRequest) return;
      _setState(MediaSearchSuccess(items));
    } on MediaSearchException catch (error) {
      if (requestId != _latestRequest) return;
      _setState(MediaSearchFailure(error.message));
    }
  }

  void clear() {
    _latestRequest++;
    _setState(MediaSearchIdle(trendingItems: _trendingItems));
  }

  void _setState(MediaSearchState state) {
    _state = state;
    notifyListeners();
  }
}
