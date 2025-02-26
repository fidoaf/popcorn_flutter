import 'package:flutter/material.dart';
import 'package:popcorn_flutter/player/view/media_player_controller.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

class MediaInfoDetails extends StatefulWidget {
  final MediaInfo info;
  const MediaInfoDetails({super.key, required this.info});

  @override
  State<StatefulWidget> createState() => MediaInfoDetailsState();
}

class MediaInfoDetailsState extends State<MediaInfoDetails> {
  final _controller = const MediaPlayerController();

  // TODO: Check media
  final bool _isCheckingMedia = false;

  MediaInfoDetailsState();

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final poster = info.image;
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: _isCheckingMedia
          ? const FloatingActionButton.large(onPressed: null, child: CircularProgressIndicator())
          : FloatingActionButton.large(onPressed: () => _controller.openPlayer(info), child: const Icon(Icons.play_circle)),
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
