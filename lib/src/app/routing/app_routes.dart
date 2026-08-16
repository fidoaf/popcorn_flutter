import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Named routes for the whole app.
///
/// Encoding the media type and id in the path (e.g. `/details/movie/603`)
/// makes movie/TV pages deep-linkable: the same URL that the app pushes while
/// navigating can be opened cold from a browser address bar or an App Link.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String landing = '/';
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String history = '/history';
  static const String trailer = '/trailer';
  static const String privacy = '/privacy';
  static const String terms = '/terms';

  /// `/search/{movie|tv}?q={query}`.
  static String search(String query, {MediaType type = MediaType.movie}) => '/search/${type.name}?q=${Uri.encodeQueryComponent(query)}';

  /// `/details/{movie|tv}/{id}`.
  static String details(MediaType type, int id) => '/details/${type.name}/$id';

  /// `/watch/{movie|tv}/{id}` with optional `?season=&episode=` for TV.
  static String watch(MediaType type, int id, {int? season, int? episode}) {
    final path = '/watch/${type.name}/$id';
    final query = <String, String>{if (season != null) 'season': '$season', if (episode != null) 'episode': '$episode'};
    if (query.isEmpty) return path;
    return '$path?${query.entries.map((e) => '${e.key}=${e.value}').join('&')}';
  }

  /// Parses a route [name] into a structured [AppRouteRequest].
  static AppRouteRequest parse(String? name) {
    final uri = Uri.parse(name ?? landing);
    final segments = uri.pathSegments;
    if (segments.isEmpty) return const LandingRoute();
    switch (segments.first) {
      case 'home':
        return const HomeRoute();
      case 'favorites':
        return const FavoritesRoute();
      case 'history':
        return const HistoryRoute();
      case 'trailer':
        return const TrailerRoute();
      case 'privacy':
        return const PrivacyRoute();
      case 'terms':
        return const TermsRoute();
      case 'search':
        return SearchRoute(query: uri.queryParameters['q'] ?? '', type: _parseType(segments.length > 1 ? segments[1] : null));
      case 'details':
        final parsed = _parseTypeId(segments);
        return parsed == null ? const UnknownRoute() : DetailsRoute(type: parsed.$1, id: parsed.$2);
      case 'watch':
        final parsed = _parseTypeId(segments);
        if (parsed == null) return const UnknownRoute();
        return WatchRoute(
          type: parsed.$1,
          id: parsed.$2,
          season: int.tryParse(uri.queryParameters['season'] ?? ''),
          episode: int.tryParse(uri.queryParameters['episode'] ?? ''),
        );
      default:
        return const UnknownRoute();
    }
  }

  static (MediaType, int)? _parseTypeId(List<String> segments) {
    if (segments.length < 3) return null;
    final id = int.tryParse(segments[2]);
    if (id == null) return null;
    for (final type in MediaType.values) {
      if (type.name == segments[1]) return (type, id);
    }
    return null;
  }

  static MediaType _parseType(String? name) {
    for (final type in MediaType.values) {
      if (type.name == name) return type;
    }
    return MediaType.movie;
  }

  /// Whether [name] resolves to a page that is reachable without signing in.
  static bool isPublic(String? name) {
    final request = parse(name);
    return request is LandingRoute || request is PrivacyRoute || request is TermsRoute;
  }
}

/// A parsed route target produced by [AppRoutes.parse].
sealed class AppRouteRequest {
  const AppRouteRequest();
}

/// Public landing page shown at `/`; describes the app without requiring sign-in.
class LandingRoute extends AppRouteRequest {
  const LandingRoute();
}

class HomeRoute extends AppRouteRequest {
  const HomeRoute();
}

class FavoritesRoute extends AppRouteRequest {
  const FavoritesRoute();
}

class HistoryRoute extends AppRouteRequest {
  const HistoryRoute();
}

class TrailerRoute extends AppRouteRequest {
  const TrailerRoute();
}

class PrivacyRoute extends AppRouteRequest {
  const PrivacyRoute();
}

class TermsRoute extends AppRouteRequest {
  const TermsRoute();
}

class SearchRoute extends AppRouteRequest {
  const SearchRoute({required this.query, required this.type});

  final String query;
  final MediaType type;
}

class DetailsRoute extends AppRouteRequest {
  const DetailsRoute({required this.type, required this.id});

  final MediaType type;
  final int id;
}

class WatchRoute extends AppRouteRequest {
  const WatchRoute({required this.type, required this.id, this.season, this.episode});

  final MediaType type;
  final int id;
  final int? season;
  final int? episode;
}

class UnknownRoute extends AppRouteRequest {
  const UnknownRoute();
}
