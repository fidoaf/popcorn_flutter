import 'package:popcorn_flutter/src/player/infrastructure/media_source/configurable_media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/provider/nxsha_media_source_provider.dart';

/// Builds the [ConfigurableMediaSourceProvider] used by the app, seeded with
/// the default streaming backend so the resolution strategy can be swapped at
/// runtime.
abstract final class MediaSourceProviderFactory {
  const MediaSourceProviderFactory._();

  static ConfigurableMediaSourceProvider create() => ConfigurableMediaSourceProvider(initialProvider: const NxshaMediaSourceProvider());
}
