import 'package:flutter/material.dart';
import 'package:popcorn_flutter/player/view/media_player_controller.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';

class MediaInfoDetails extends StatefulWidget {
  final MediaInfo info;
  const MediaInfoDetails({super.key, required this.info});

  @override
  State<StatefulWidget> createState() => MediaInfoDetailsState();
}

class MediaInfoDetailsState extends State<MediaInfoDetails> {
  final _controller = const MediaPlayerController();

  MediaInfoDetailsState();

  bool _isModified = false;

  bool _isMediaFavorite(MediaInfo info) {
    return _controller.isFavorite(info);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final poster = info.image;
    final isFavorite = _isMediaFavorite(info);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop<bool>(context, _isModified);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            color: isFavorite ? Colors.red : Colors.white,
            onPressed: () async {
              isFavorite ? await _controller.removeFavorite(info) : await _controller.addFavorite(info);
              _isModified = true;
              setState(() {});
            },
          )
        ],
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _controller.isAvailable(info),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final isAvailable = snapshot.data == true;
            return isAvailable
                ? FloatingActionButton.large(onPressed: () => _controller.openPlayer(info), child: const Icon(Icons.play_circle))
                : const FloatingActionButton.large(onPressed: null, backgroundColor: Colors.red, child: Icon(Icons.close));
          } else {
            return const FloatingActionButton.large(onPressed: null, child: CircularProgressIndicator());
          }
        },
      ),
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
                    FutureBuilder<MediaInfoResult>(
                      future: _controller.getDetails(info),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final details = snapshot.data?.details;
                          return details == null ? const Wrap() : Text(details.id);
                        } else {
                          return const Wrap();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
