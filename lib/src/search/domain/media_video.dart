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
    if (site == 'YouTube') return Uri.parse('https://www.youtube.com/embed/$key?autoplay=1');
    if (site == 'Vimeo') return Uri.parse('https://player.vimeo.com/video/$key?autoplay=1');
    return null;
  }

  /// Returns a self-contained HTML document that hosts this video, or `null`
  /// when navigating directly to [embedUrl] is sufficient.
  ///
  /// YouTube's anti-abuse checks reject a bare `/embed/` navigation inside a
  /// WebView (surfaced as "error 153" / "error 152-4"). Reliable embedded
  /// playback additionally requires a `strict-origin-when-cross-origin`
  /// referrer policy (declared both as a `<meta>` tag and on the iframe) and a
  /// realistic, non-`youtube.com` document origin — which the player supplies
  /// as the base URL when it renders this markup via `MediaSource.data`.
  String? get embedHtml {
    if (site != 'YouTube') return null;
    final src = 'https://www.youtube.com/embed/$key?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1';
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="referrer" content="strict-origin-when-cross-origin">
    <style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style>
  </head>
  <body>
    <iframe
      src="$src"
      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"></iframe>
  </body>
</html>
''';
  }
}
