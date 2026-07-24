import 'dart:typed_data';

/// The HTTP method used to request a [MediaSource].
enum MediaSourceMethod {
  get('GET'),
  post('POST');

  const MediaSourceMethod(this.value);

  /// The HTTP verb as understood by the underlying network/WebView stack.
  final String value;
}

/// A single cookie that must accompany a [MediaSource] request.
final class MediaCookie {
  const MediaCookie({required this.name, required this.value, this.domain, this.path = '/'});

  final String name;
  final String value;
  final String? domain;
  final String path;
}

/// Immutable description of everything required to load a playable media
/// stream: the final [url] plus the HTTP [method], [headers], [cookies] and
/// optional request [body].
///
/// The video player consumes a [MediaSource] and stays agnostic of how it was
/// built; concrete backends are produced by a `MediaSourceProvider`.
final class MediaSource {
  const MediaSource({
    required this.url,
    this.method = MediaSourceMethod.get,
    this.headers = const <String, String>{},
    this.cookies = const <MediaCookie>[],
    this.body,
    this.data,
  });

  final Uri url;
  final MediaSourceMethod method;
  final Map<String, String> headers;
  final List<MediaCookie> cookies;
  final Uint8List? body;

  /// Optional self-contained HTML document to render instead of navigating to
  /// [url]. When present, the player loads this markup using [url] as the base
  /// URL (so its origin/referrer is honoured). Used to host embedded players
  /// that reject a bare navigation (e.g. YouTube inside a WebView).
  final String? data;
}
