import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/search/domain/movie_search_exception.dart';
import 'package:popcorn_flutter/src/search/domain/movie_search_repository.dart';
import 'package:popcorn_flutter/src/search/view/movie_search_state.dart';

/// Drives movie searches and exposes the resulting [MovieSearchState].
///
/// Depends only on the [MovieSearchRepository] abstraction, so it works with
/// any data source and is trivial to unit test.
class MovieSearchController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  MovieSearchController({required MovieSearchRepository repository}) : _repository = repository;

  final MovieSearchRepository _repository;

  MovieSearchState _state = const MovieSearchIdle();
  MovieSearchState get state => _state;

  // Guards against out-of-order responses when searches are issued rapidly.
  int _latestRequest = 0;

  Future<void> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      clear();
      return;
    }

    final requestId = ++_latestRequest;
    _setState(const MovieSearchLoading());

    try {
      final movies = await _repository.search(trimmedQuery);
      if (requestId != _latestRequest) return;
      _setState(MovieSearchSuccess(movies));
    } on MovieSearchException catch (error) {
      if (requestId != _latestRequest) return;
      _setState(MovieSearchFailure(error.message));
    }
  }

  void clear() {
    _latestRequest++;
    _setState(const MovieSearchIdle());
  }

  void _setState(MovieSearchState state) {
    _state = state;
    notifyListeners();
  }
}
