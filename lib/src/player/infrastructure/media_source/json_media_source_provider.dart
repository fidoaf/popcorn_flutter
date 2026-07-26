import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_definition.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaSourceProvider] driven entirely by a [MediaSourceProviderDefinition].
///
/// This replaces the previous hand-written per-backend providers: every backend
/// is now expressed as data (see `MediaSourceProviderDefinition.fromJson`), so
/// new streaming hosts can be added by editing JSON instead of Dart.
final class JsonMediaSourceProvider implements MediaSourceProvider {
  const JsonMediaSourceProvider(this.definition);

  final MediaSourceProviderDefinition definition;

  @override
  MediaSource resolve(MediaItem media, MediaType mediaType) => definition.buildRequest(media, mediaType);
}
