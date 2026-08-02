import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Resolves the [MediaSource] that should be played for a catalogue entry.
///
/// Implementations encapsulate how a [MediaItem] of a given [MediaType] maps to
/// a concrete request (URL, method, headers, cookies, body), keeping the player
/// decoupled from any particular streaming backend. The active provider can be
/// swapped at runtime through `ConfigurableMediaSourceProvider`.
///
/// For TV series, [season] and [episode] select the episode to play; they are
/// ignored for movies.
abstract interface class MediaSourceProvider {
  MediaSource resolve(MediaItem media, MediaType mediaType, {int? season, int? episode});
}
