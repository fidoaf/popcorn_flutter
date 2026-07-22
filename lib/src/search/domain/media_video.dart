/// A video (trailer, teaser, clip, etc.) associated with a media item.
final class MediaVideo {
  const MediaVideo({required this.id, required this.key, required this.name, required this.site, required this.type});

  final String id;

  /// The video key on the hosting site (e.g. a YouTube video ID).
  final String key;

  final String name;

  /// Hosting site name (e.g. "YouTube", "Vimeo").
  final String site;

  /// Video type (e.g. "Trailer", "Teaser", "Clip").
  final String type;

  /// Returns the playable URL for this video, or `null` if the site is unsupported.
  Uri? get url {
    if (site == 'YouTube') return Uri.parse('https://www.youtube.com/watch?v=$key');
    if (site == 'Vimeo') return Uri.parse('https://vimeo.com/$key');
    return null;
  }

  /// Returns an embeddable URL suitable for in-app WebView playback,
  /// or `null` if the site is unsupported.
  Uri? get embedUrl {
    if (site == 'YouTube') return Uri.parse('https://www.youtube.com/watch?v=$key');
    if (site == 'Vimeo') return Uri.parse('https://vimeo.com/$key');
    return null;
  }
}
