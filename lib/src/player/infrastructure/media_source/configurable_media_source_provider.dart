import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/media_source_preferences.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaSourceProvider] whose backing [delegate] can be swapped at any time.
///
/// Callers keep a single stable reference while the actual source-resolution
/// strategy (e.g. a different streaming backend) is replaced on the fly.
final class ConfigurableMediaSourceProvider implements MediaSourceProvider {
  ConfigurableMediaSourceProvider({required this.providers, required this.preferences, MediaSourceProvider? initialProvider})
    : delegate = initialProvider ?? providers.first;

  /// The active provider. Assigning a new value takes effect immediately for
  /// every subsequent [resolve] call.
  MediaSourceProvider delegate;

  Iterable<MediaSourceProvider> providers;

  /// Externally-controlled playback preferences (language, subtitles) shared
  /// with every delegate. Mutating this affects subsequent [resolve] calls.
  final MediaSourcePreferences preferences;

  @override
  MediaSource resolve(MediaItem media, MediaType mediaType) => delegate.resolve(media, mediaType);
}
