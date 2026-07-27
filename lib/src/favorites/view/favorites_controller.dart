import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorite_media.dart';
import 'package:popcorn_flutter/src/favorites/domain/favorites_repository.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Holds the user's favorite media and keeps it in sync with the
/// [FavoritesRepository].
///
/// Depends only on the [FavoritesRepository] abstraction, so it works with any
/// storage backend and is trivial to unit test.
class FavoritesController extends ChangeNotifier {
  // ignore: prefer_initializing_formals -- named parameters cannot be private.
  FavoritesController({required FavoritesRepository repository}) : _repository = repository {
    _load();
  }

  final FavoritesRepository _repository;

  List<FavoriteMedia> _favorites = const [];

  /// The favorites in insertion order (most recently added last).
  List<FavoriteMedia> get favorites => List.unmodifiable(_favorites);

  /// Whether the entry [id] of [type] is currently a favorite.
  bool isFavorite(MediaType type, int id) => _favorites.any((favorite) => favorite.matches(type, id));

  /// Adds [media] to the favorites when absent, or removes it when present, and
  /// persists the change.
  Future<void> toggle(FavoriteMedia media) async {
    if (isFavorite(media.type, media.item.id)) {
      _favorites = _favorites.where((favorite) => !favorite.matches(media.type, media.item.id)).toList();
    } else {
      _favorites = [..._favorites, media];
    }
    notifyListeners();
    await _repository.save(_favorites);
  }

  /// Removes the entry [id] of [type] from the favorites and persists the change.
  Future<void> remove(MediaType type, int id) async {
    if (!isFavorite(type, id)) return;
    _favorites = _favorites.where((favorite) => !favorite.matches(type, id)).toList();
    notifyListeners();
    await _repository.save(_favorites);
  }

  Future<void> _load() async {
    _favorites = await _repository.load();
    notifyListeners();
  }
}
