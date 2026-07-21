import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A [MediaSourceProvider] whose backing [delegate] can be swapped at any time.
///
/// Callers keep a single stable reference while the actual source-resolution
/// strategy (e.g. a different streaming backend) is replaced on the fly.
final class ConfigurableMediaSourceProvider implements MediaSourceProvider {
  ConfigurableMediaSourceProvider({required MediaSourceProvider initialProvider}) : _delegate = initialProvider;

  MediaSourceProvider _delegate;

  /// The active provider. Assigning a new value takes effect immediately for
  /// every subsequent [resolve] call.
  MediaSourceProvider get delegate => _delegate;
  set delegate(MediaSourceProvider provider) => _delegate = provider;

  @override
  MediaSource resolve(MediaItem media, MediaType mediaType) => _delegate.resolve(media, mediaType);
}
