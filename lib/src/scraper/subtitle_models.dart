/// Data models used by [SubtitleService].
///
/// These mirror the JSON shapes returned by the original Node/Express server
/// (`/movie-subtitles`, `/tv-subtitles`) but are expressed as immutable Dart
/// value objects.
library;

/// Human-readable names for the subtitle languages the service supports.
///
/// Mirrors `LANGUAGE_NAMES` from the original server. Extend this map to add
/// more languages; [commonLanguages] is derived from its keys.
const Map<String, String> languageNames = <String, String>{'en': 'English'};

/// The set of ISO language codes the service will accept, derived from
/// [languageNames]. Mirrors `COMMON_LANGUAGES`.
final List<String> commonLanguages = languageNames.keys.toList(growable: false);

/// A subtitle candidate discovered on OpenSubtitles before its download URL has
/// been resolved.
///
/// Produced by [SubtitleService.searchSubtitles]; [fileId] is later exchanged
/// for a temporary download link.
class SubtitleCandidate {
  const SubtitleCandidate({required this.language, required this.languageName, required this.fileId, this.downloadCount = 0});

  final String language;
  final String languageName;
  final int fileId;
  final int downloadCount;
}

/// A fully-resolved subtitle track with a ready-to-use [url].
class SubtitleTrack {
  const SubtitleTrack({required this.language, required this.languageName, required this.url});

  final String language;
  final String languageName;
  final String url;

  Map<String, Object?> toJson() => <String, Object?>{'language': language, 'language_name': languageName, 'url': url};
}

/// The result of a movie subtitle lookup, matching the `/movie-subtitles`
/// response envelope.
class MovieSubtitlesResult {
  const MovieSubtitlesResult({required this.subtitles, required this.tmdbId, required this.imdbId, required this.type});

  final List<SubtitleTrack> subtitles;
  final String tmdbId;
  final String imdbId;
  final String type;

  Map<String, Object?> toJson() => <String, Object?>{
    'success': true,
    'subtitles': subtitles.map((SubtitleTrack s) => s.toJson()).toList(),
    'meta': <String, Object?>{'tmdb_id': tmdbId, 'imdb_id': imdbId, 'type': type},
  };
}

/// Thrown when a subtitle operation fails. Carries an optional HTTP-style
/// [statusCode] so callers can map failures onto their own responses.
class SubtitleException implements Exception {
  const SubtitleException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SubtitleException($statusCode): $message';
}
