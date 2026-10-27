import 'provider_registry.dart';

final class MediaRequest {
  const MediaRequest({
    required this.providerId,
    required this.type,
    required this.id,
    required this.lang,
    required this.sub,
    required this.season,
    required this.episode,
  });

  final String providerId;
  final String type;
  final String id;
  final String lang;
  final String sub;
  final String season;
  final String episode;

  factory MediaRequest.parse(
    Map<String, String> parameters, {
    required MediaProviderRegistry providers,
  }) {
    final requestedProvider = parameters['provider'];
    final providerId = requestedProvider == null || requestedProvider.isEmpty
        ? providers.defaultProviderId
        : requestedProvider;
    if (!providers.contains(providerId)) {
      throw const InvalidMediaRequest('Unsupported media provider');
    }

    final requestedType = parameters['type'];
    final type =
        (requestedType == null || requestedType.isEmpty
                ? 'movie'
                : requestedType)
            .toLowerCase();
    final requestedId = parameters['id'];
    final fallbackId = parameters['imdbId'];
    final id =
        (requestedId == null || requestedId.isEmpty
                ? fallbackId ?? ''
                : requestedId)
            .trim();
    final requestedLanguage = parameters['lang'];
    final lang =
        (requestedLanguage == null || requestedLanguage.isEmpty
                ? 'en'
                : requestedLanguage)
            .trim()
            .toLowerCase();
    final requestedSubtitles = parameters['sub'];
    final sub = requestedSubtitles == null || requestedSubtitles.isEmpty
        ? '1'
        : requestedSubtitles;

    if (!{'movie', 'tv'}.contains(type) ||
        !RegExp(r'^(tt\d+|\d+)$').hasMatch(id)) {
      throw const InvalidMediaRequest(
        'Provide a valid movie/TV type and IMDb or TMDB ID',
      );
    }
    if (!RegExp(r'^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$').hasMatch(lang)) {
      throw const InvalidMediaRequest(
        'Language must be a valid language code, for example en',
      );
    }
    if (sub != '0' && sub != '1') {
      throw const InvalidMediaRequest('Subtitles must be set to 0 or 1');
    }

    if (type == 'movie') {
      return MediaRequest(
        providerId: providerId,
        type: type,
        id: id,
        lang: lang,
        sub: sub,
        season: '0',
        episode: '0',
      );
    }

    final season = parameters['season'] ?? '';
    final episode = parameters['episode'] ?? '';
    final positiveInteger = RegExp(r'^[1-9]\d*$');
    if (!positiveInteger.hasMatch(season) ||
        !positiveInteger.hasMatch(episode)) {
      throw const InvalidMediaRequest(
        'TV shows require positive season and episode numbers',
      );
    }
    return MediaRequest(
      providerId: providerId,
      type: type,
      id: id,
      lang: lang,
      sub: sub,
      season: season,
      episode: episode,
    );
  }
}

final class InvalidMediaRequest implements Exception {
  const InvalidMediaRequest(this.message);

  final String message;

  @override
  String toString() => message;
}
