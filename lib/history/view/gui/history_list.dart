import 'package:flutter/material.dart';
import 'package:popcorn_flutter/history/view/media_history_controller.dart';
import 'package:popcorn_flutter/details/view/gui/media_info_details_view.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

class HistoryListView extends StatefulWidget {
  const HistoryListView({super.key});

  @override
  State<StatefulWidget> createState() => HistoryListViewState();
}

class HistoryListViewState extends State<HistoryListView> {
  final _controller = MediaHistoryController();

  final _historyList = <MediaInfo>[];

  @override
  void initState() {
    _refresh();
    //
    super.initState();
  }

  void _refresh() {
    final list = _controller.getHistoryList();
    setState(() {
      _historyList
        ..clear()
        ..addAll(list);
    });
  }

  void _showMediaDetails(MediaInfo fav) {
    Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => MediaInfoDetails(info: fav), settings: RouteSettings(name: '/${fav.id}/details'))).then((refresh) {
      if (refresh == true) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_historyList.isEmpty) {
      return const Wrap();
    } else {
      return ConstrainedBox(
        constraints: const BoxConstraints.tightForFinite(height: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Continue watching", style: TextStyle(fontWeight: FontWeight.bold)),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              children:
                  _historyList.map((fav) {
                    return _FavoriteItemView(info: fav, onSelected: (item) => _showMediaDetails(item), onRemoved: (item) => _refresh());
                  }).toList(),
            ),
          ],
        ),
      );
    }
  }
}

class _FavoriteItemView extends StatefulWidget {
  final MediaInfo info;
  final Function(MediaInfo) onSelected;
  final Function(MediaInfo) onRemoved;
  const _FavoriteItemView({required this.info, required this.onSelected, required this.onRemoved});

  @override
  State<StatefulWidget> createState() => _FavoriteItemViewState();
}

class _FavoriteItemViewState extends State<_FavoriteItemView> {
  final _controller = MediaHistoryController();

  bool _selected = false;

  void _updateHover(bool selected) {
    setState(() {
      _selected = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final poster = info.image?.url;
    final Widget content;

    content = Stack(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MediaInfoDetails(info: info), settings: RouteSettings(name: '/${info.id}/details'))).then((refresh) {
              if (refresh == true) {
                if (_controller.isWatching(info)) {
                } else {
                  widget.onRemoved(info);
                }
              }
            });
          },
          child: Center(
            child: Card(
              elevation: _selected ? 5 : 1,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (poster != null)
                      Expanded(
                        child: Image.network(
                          poster,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        ),
                      ),
                    Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_selected)
          Align(
            alignment: Alignment.topRight,
            child: IconButton.outlined(
              onPressed: () async {
                final success = await _controller.removeFromHistory(info);
                if (success) widget.onRemoved(info);
              },
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration:
            _selected
                ? const BoxDecoration(
                  // borderRadius: BorderRadius.circular(8),
                  // border: Border.all(color: Colors.grey),
                )
                : null,
        child: content,
      ),
      onEnter: (_) => _updateHover(true),
      onExit: (_) => _updateHover(false),
    );
  }
}
