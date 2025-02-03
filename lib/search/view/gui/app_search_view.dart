import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/view/gui/transition_page.dart';
import 'package:popcorn_flutter/player/view/media_player_controller.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/view/media_search_controller.dart';
import 'package:popcorn_flutter/shared/view/list/paginator.dart';

class MediaSearchFormPage extends StatefulWidget {
  const MediaSearchFormPage({super.key});

  @override
  State<StatefulWidget> createState() => _MediaSearchFormPageState();
}

class _MediaSearchFormPageState extends State<MediaSearchFormPage> {
  final _controller = MediaSearchController();
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _MediaSearchFormPageState();

  bool _isLoading = false;
  MediaType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    final AppBar? appBar;
    if (_isLoading) {
      appBar = null;
      content = const LoadingWidget();
    } else {
      appBar = null;
      content = Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('What would you like to watch?'),
                TextFormField(
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  controller: _textController,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    return value == null || value.isEmpty ? 'You must input search terms' : null;
                  },
                  onFieldSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 32),
                SegmentedButton(
                  segments: MediaType.values.map((mt) => ButtonSegment<MediaType>(value: mt, label: Text(mt.name.toUpperCase()))).toList(),
                  selected: _selectedType == null ? const {} : {_selectedType},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (newSel) => setState(() {
                    _selectedType = newSel.isEmpty ? null : newSel.first;
                  }),
                ),
                const SizedBox(height: 32),
                OutlinedButton(onPressed: _search, child: const Text('SEARCH'))
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: content,
      appBar: appBar,
    );
  }

  void _search() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() => _isLoading = true);
      final results = await _controller.search(terms: _textController.text, type: _selectedType);
      _showDetails(results);
      setState(() => _isLoading = false);
    }
  }

  void _showDetails(MediaSearchResult results) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => _MediaSearchResultsPage(originalSearch: _textController.text, searchResult: results))).then((_) {
      setState(() {
        _textController.clear();
        _selectedType = null;
      });
    });
  }
}

class _MediaSearchResultsPage extends StatefulWidget {
  final String originalSearch;
  final MediaType? originalType;
  final MediaSearchResult searchResult;
  const _MediaSearchResultsPage({required this.originalSearch, required this.searchResult, this.originalType});

  @override
  State<StatefulWidget> createState() => _MediaSearchResultsPageState();
}

class _MediaSearchResultsPageState extends State<_MediaSearchResultsPage> {
  final _controller = MediaSearchController();
  int _currentPage = 0;
  bool _isLoading = false;
  MediaSearchResult? _currentResult;

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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search results for: ${widget.originalSearch}'),
              Text('${results.totalCount} matches'),
            ],
          ),
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
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
                      return InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => MediaInfoDetails(info: item)));
                        },
                        child: Card(
                          key: ValueKey(item.name),
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: Text(item.dateExplanation),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite),
                              color: false ? Colors.red : Colors.white,
                              onPressed: () {},
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: Colors.white,
              child: Center(
                child: Paginator(
                  totalCount: results.totalCount,
                  currentPage: _currentPage,
                  onPageChanged: (index) {
                    _currentPage = index;
                    _refresh();
                  },
                ),
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
                  Navigator.pop(context);
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

class MediaInfoDetails extends StatelessWidget {
  final MediaInfo info;
  final _controller = const MediaPlayerController();
  const MediaInfoDetails({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final poster = info.image;
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton.large(onPressed: () => _controller.openPlayer(info), child: const Icon(Icons.play_circle)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: poster == null
          ? const Wrap()
          : Container(
              foregroundDecoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(poster.url),
                  fit: BoxFit.fitHeight,
                  opacity: 0.2,
                ),
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      info.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      info.dateExplanation,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
