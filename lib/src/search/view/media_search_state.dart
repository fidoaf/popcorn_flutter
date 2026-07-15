import 'package:popcorn_flutter/src/search/domain/media_item.dart';

/// Presentation state of a media search, consumed by the views.
sealed class MediaSearchState {
  const MediaSearchState();
}

/// No search has been performed yet.
final class MediaSearchIdle extends MediaSearchState {
  const MediaSearchIdle();
}

/// A search request is in flight.
final class MediaSearchLoading extends MediaSearchState {
  const MediaSearchLoading();
}

/// A search completed successfully with [items] (possibly empty).
final class MediaSearchSuccess extends MediaSearchState {
  const MediaSearchSuccess(this.items);

  final List<MediaItem> items;
}

/// A search failed with a human-readable [message].
final class MediaSearchFailure extends MediaSearchState {
  const MediaSearchFailure(this.message);

  final String message;
}
