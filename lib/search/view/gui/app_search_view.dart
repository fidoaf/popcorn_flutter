import 'package:flutter/material.dart';
import 'package:popcorn_flutter/app/view/gui/transition_page.dart';
import 'package:popcorn_flutter/player/view/media_player_controller.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/view/media_search_controller.dart';

class AppSearchView extends StatefulWidget {
  const AppSearchView({super.key});

  @override
  State<StatefulWidget> createState() => _AppSearchViewState();
}

class _AppSearchViewState extends State<AppSearchView> {
  final _controller = const MediaSearchController();
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _AppSearchViewState();

  bool _isLoading = false;
  MediaType? _selectedType;
  MediaSearchResult? _currentResults;

  @override
  Widget build(BuildContext context) {
    final results = _currentResults;
    final Widget content;
    final AppBar? appBar;
    if (_isLoading) {
      appBar = null;
      content = const LoadingWidget();
    } else {
      if (results == null) {
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
      } else {
        final items = [...results.items, ...results.items, ...results.items];
        appBar = AppBar(
          leading: IconButton(
            onPressed: () {
              setState(() {
                _textController.text = '';
                _currentResults = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
          ),
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
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
            const Center(child: Text('paginator')),
          ],
        );
      }
    }
    return Scaffold(
      body: content,
      appBar: appBar,
    );
  }

  void _search() async {
    if (_formKey.currentState?.validate() == true) {
      setState(() => _isLoading = true);
      final result = await _controller.search(terms: _textController.text);
      _currentResults = result;
      setState(() => _isLoading = false);
    }
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
