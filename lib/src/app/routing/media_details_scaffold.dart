import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/search/search.dart';

/// The resolved data handed to a platform detail builder.
class MediaDetailsBundle {
  const MediaDetailsBundle({required this.item, required this.type, required this.details, required this.videos});

  final MediaItem item;
  final MediaType type;
  final Future<MediaDetails> details;
  final Future<List<MediaVideo>> videos;
}

/// Resolves the [MediaItem] for a details route — using [item] when navigating
/// within the app, or fetching it by [id]/[type] for a cold-start deep link —
/// then builds the platform details page once via [builder].
///
/// The extended details/videos futures are created a single time when the item
/// resolves, so route rebuilds never re-issue the network requests.
class MediaDetailsScaffold extends StatefulWidget {
  const MediaDetailsScaffold({
    super.key,
    required this.id,
    required this.type,
    required this.repository,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.builder,
    this.item,
  });

  final int id;
  final MediaType type;
  final MediaItem? item;
  final MediaSearchRepository repository;
  final WidgetBuilder loadingBuilder;
  final Widget Function(BuildContext context, Object error) errorBuilder;
  final Widget Function(BuildContext context, MediaDetailsBundle bundle) builder;

  @override
  State<MediaDetailsScaffold> createState() => _MediaDetailsScaffoldState();
}

class _MediaDetailsScaffoldState extends State<MediaDetailsScaffold> {
  MediaItem? _item;
  Object? _error;
  Future<MediaDetails>? _details;
  Future<List<MediaVideo>>? _videos;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _resolve(item);
    } else {
      widget.repository
          .mediaItem(widget.id, widget.type)
          .then((value) {
            if (mounted) setState(() => _resolve(value));
          })
          .catchError((Object error) {
            if (mounted) setState(() => _error = error);
          });
    }
  }

  void _resolve(MediaItem item) {
    _item = item;
    _details = widget.repository.details(item.id, widget.type);
    _videos = widget.repository.videos(item.id, widget.type);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return widget.errorBuilder(context, error);
    final item = _item;
    if (item == null) return widget.loadingBuilder(context);
    return widget.builder(context, MediaDetailsBundle(item: item, type: widget.type, details: _details!, videos: _videos!));
  }
}
