import 'package:flutter/material.dart';
import 'package:popcorn_flutter/player/view/media_player_controller.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';

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
