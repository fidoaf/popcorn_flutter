import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:popcorn_flutter/src/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/src/search/view/media_search_state.dart';

/// Mixin that encapsulates the shared logic for media search views.
///
/// Provides text controller lifecycle management, submit/clear actions,
/// and the state-machine body builder that delegates to platform-specific
/// template methods.
mixin MediaSearchViewMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController queryController = TextEditingController();

  /// The [MediaSearchController] driving the search.
  MediaSearchController get searchController;

  /// Called when a result row is tapped.
  ValueChanged<MediaItem>? get onMediaSelected;

  /// Called when a result's play button is tapped.
  ValueChanged<MediaItem>? get onMediaPlay;

  /// Optional query to prefill and run when the view is first shown, used to
  /// open the search page from a deep link. `null`/empty means no initial search.
  String? get initialQuery => null;

  /// Optional catalogue to select before running [initialQuery].
  MediaType? get initialMediaType => null;

  // ── Template methods (platform-specific) ──────────────────────────────────

  /// Widget shown when idle and no trending items are available.
  Widget buildIdleHint(BuildContext context);

  /// Loading indicator.
  Widget buildLoading(BuildContext context);

  /// Error state widget.
  Widget buildError(BuildContext context, String message);

  /// Widget shown when search returns no results.
  Widget buildEmptyResults(BuildContext context);

  /// A single result item tile.
  Widget buildResultItem(BuildContext context, MediaItem item, int index);

  /// Header shown above the trending list.
  Widget buildTrendingHeader(BuildContext context);

  /// Optional padding for the result/trending list.
  EdgeInsets? get resultListPadding => null;

  // ── Shared lifecycle ──────────────────────────────────────────────────────

  void initSearchView() {
    final query = initialQuery;
    if (query != null && query.isNotEmpty) queryController.text = query;
    queryController.addListener(_onQueryChanged);
    final type = initialMediaType;
    if (type != null || (query != null && query.isNotEmpty)) {
      // Defer controller mutations until after the first frame so listeners are
      // not notified mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (type != null) searchController.setMediaType(type);
        if (query != null && query.isNotEmpty) searchController.search(query);
      });
    }
  }

  void disposeSearchView() {
    queryController.removeListener(_onQueryChanged);
    queryController.dispose();
  }

  void _onQueryChanged() => setState(() {});

  void submitSearch() => searchController.search(queryController.text);

  void clearSearch() {
    queryController.clear();
    searchController.clear();
  }

  /// Whether the query field currently has text (for showing/hiding the clear button).
  bool get hasQuery => queryController.text.isNotEmpty;

  // ── Shared body builder ───────────────────────────────────────────────────

  /// Builds the body content based on the current [MediaSearchState].
  Widget buildBody(BuildContext context) {
    final state = searchController.state;
    return switch (state) {
      MediaSearchIdle(:final trendingItems) when trendingItems.isNotEmpty => _buildTrendingList(context, trendingItems),
      MediaSearchIdle() => buildIdleHint(context),
      MediaSearchLoading() => buildLoading(context),
      MediaSearchFailure(:final message) => buildError(context, message),
      MediaSearchSuccess(:final items) when items.isEmpty => buildEmptyResults(context),
      MediaSearchSuccess(:final items) => ListView.builder(
        padding: resultListPadding,
        itemCount: items.length,
        itemBuilder: (context, index) => buildResultItem(context, items[index], index),
      ),
    };
  }

  Widget _buildTrendingList(BuildContext context, List<MediaItem> items) {
    return ListView.builder(
      padding: resultListPadding,
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return buildTrendingHeader(context);
        return buildResultItem(context, items[index - 1], index - 1);
      },
    );
  }
}
