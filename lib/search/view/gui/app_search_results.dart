import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/view/gui/transition_page.dart';
import 'package:popcorn_flutter/details/view/gui/media_info_details_view.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/view/gui/media_type_extension.dart';
import 'package:popcorn_flutter/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/shared/view/list/paginator_view.dart';

class MediaSearchResultsPage extends StatefulWidget {
  final String originalSearch;
  final MediaType? originalType;
  final MediaSearchResult searchResult;
  const MediaSearchResultsPage({super.key, required this.originalSearch, required this.searchResult, this.originalType});

  @override
  State<StatefulWidget> createState() => _MediaSearchResultsPageState();
}

class _MediaSearchResultsPageState extends State<MediaSearchResultsPage> {
  final _controller = MediaSearchController();
  int _currentPage = 0;
  bool _isLoading = false;

  bool _isModified = false;
  MediaSearchResult? _currentResult;

  bool _isMediaFavorite(MediaInfo info) {
    return _controller.isFavorite(info);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    final AppBar? appBar;

    if (_isLoading) {
      appBar = null;
      content = const LoadingWidget();
    } else {
      final results = _currentResult ?? widget.searchResult;
      final successfulSearch = results.success;
      if (successfulSearch) {
        final items = results.list;
        appBar = AppBar(
          toolbarHeight: 36,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search results for: ${widget.originalSearch}'),
              Text('${results.totalCount} matches'),
            ],
          ),
          leading: IconButton(
            onPressed: () {
              Navigator.pop<bool>(context, _isModified);
            },
            icon: const Icon(Icons.arrow_back),
          ),
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SingleChildScrollView(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isFavorite = _isMediaFavorite(item);
                      return InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MediaInfoDetails(info: item), settings: RouteSettings(name: '/${item.id}/details'))).then((refresh) {
                            if (refresh == true) {
                              setState(() {
                                _isModified = true;
                              });
                            }
                          });
                        },
                        child: Card(
                          key: ValueKey(item.name),
                          child: ListTile(
                            leading: item.type?.icon,
                            title: Text(item.name),
                            subtitle: Text(item.dateExplanation),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite),
                              color: isFavorite ? Colors.red : Colors.white,
                              onPressed: () async {
                                isFavorite ? await _controller.removeFavorite(item) : await _controller.addFavorite(item);
                                _isModified = true;
                                setState(() {});
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              child: PaginatorView(
                totalCount: results.totalCount,
                currentPage: _currentPage,
                onPageChanged: (index) {
                  _currentPage = index;
                  _refresh();
                },
              ),
            ),
          ],
        );
      } else {
        appBar = null;
        content = Card(
          child: AlertDialog(
            title: const Align(alignment: Alignment.centerLeft, child: Text('Error')),
            icon: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () {
                  Navigator.pop<bool>(context, _isModified);
                },
                icon: const Icon(Icons.close),
              ),
            ),
            content: Text(results.errors?.join('\n') ?? 'Unexpected error'),
          ),
        );
      }
    }

    return Scaffold(
      body: content,
      appBar: appBar,
    );
  }

  void _refresh() async {
    setState(() => _isLoading = true);
    _currentResult = await _controller.search(terms: widget.originalSearch, page: _currentPage, type: widget.originalType);
    setState(() => _isLoading = false);
  }
}
