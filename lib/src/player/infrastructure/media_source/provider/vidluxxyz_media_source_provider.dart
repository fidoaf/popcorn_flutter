import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// [MediaSourceProvider] that builds the embed URLs served by web.nxsha.app.
final class VidluxxyzMediaSourceProvider implements MediaSourceProvider {
  const VidluxxyzMediaSourceProvider();

  static const String _host = 'vidlux.xyz';

  @override
  MediaSource resolve(MediaItem media, MediaType mediaType) {
    final segment = mediaType == MediaType.tv ? 'tv' : 'movie';
    return MediaSource(url: Uri.https(_host, '/embed/$segment/${media.id}', const {'lang': 'en', 'sub': '1'}));
  }
}
