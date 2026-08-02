import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_preferences.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_provider_definition.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaSourceProvider] driven entirely by a [MediaSourceProviderDefinition].
///
/// This replaces the previous hand-written per-backend providers: every backend
/// is now expressed as data (see `MediaSourceProviderDefinition.fromJson`), so
/// new streaming hosts can be added by editing JSON instead of Dart.
///
/// Runtime, externally-controlled values (language, subtitles) are injected via
/// the shared [preferences] rather than baked into the definition.
final class JsonMediaSourceProvider implements MediaSourceProvider {
  const JsonMediaSourceProvider(this.definition, {this.preferences});

  final MediaSourceProviderDefinition definition;

  /// Playback preferences whose values are substituted into the request
  /// template at [resolve] time. When null no extra placeholders are provided.
  final MediaSourcePreferences? preferences;

  @override
  MediaSource resolve(MediaItem media, MediaType mediaType, {int? season, int? episode}) =>
      definition.buildRequest(media, mediaType, variables: preferences?.variables ?? const <String, String>{}, season: season, episode: episode);
}
