import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/view/gui/transition_page.dart';
import 'package:popcorn_flutter/favorite/view/gui/favorite_list.dart';
import 'package:popcorn_flutter/history/view/gui/history_list.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/view/gui/app_search_results.dart';
import 'package:popcorn_flutter/search/view/media_search_controller.dart';

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
  GlobalKey? _histKey;
  GlobalKey? _favKey;

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
                Column(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SegmentedButton(
                          segments: MediaType.values.map((mt) => ButtonSegment<MediaType>(value: mt, label: Text(mt.name.toUpperCase()))).toList(),
                          selected: _selectedType == null ? const {} : {_selectedType},
                          emptySelectionAllowed: true,
                          onSelectionChanged:
                              (newSel) => setState(() {
                                _selectedType = newSel.isEmpty ? null : newSel.first;
                              }),
                        ),
                        OutlinedButton(onPressed: _search, child: const Text('SEARCH')),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Flexible(flex: 4, child: HistoryListView(key: _histKey)),
                Flexible(flex: 4, child: FavoriteListView(key: _favKey)),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(body: content, appBar: appBar);
  }

  void _search() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() => _isLoading = true);
      final results = await _controller.search(terms: _textController.text, type: _selectedType);
      _showDetails(results);
      setState(() => _isLoading = false);
    }
  }

  void _showDetails(MediaSearchResult results) async {
    Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => MediaSearchResultsPage(originalSearch: _textController.text, searchResult: results))).then((refresh) {
      setState(() {
        _textController.clear();
        _selectedType = null;
        if (refresh == true) _favKey = GlobalKey();
      });
    });
  }
}
