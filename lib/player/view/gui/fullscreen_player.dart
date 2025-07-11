import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';

class FullScreenMediaPlayer extends StatefulWidget {
  final MediaPlayerSettings playerSettings;
  final Future<MediaPlayerSettings?> Function()? onPreviousEpisodeRequested;
  final Future<MediaPlayerSettings?> Function()? onNextEpisodeRequested;
  const FullScreenMediaPlayer({
    super.key,
    required this.playerSettings,
    this.onPreviousEpisodeRequested,
    this.onNextEpisodeRequested,
  });

  @override
  State<StatefulWidget> createState() => _FullScreenMediaPlayerState();
}

class _FullScreenMediaPlayerState extends State<FullScreenMediaPlayer> {
  late MediaPlayerSettings currentSettings = widget.playerSettings;

  late final bool _hasPreviousEpisode =
      widget.onPreviousEpisodeRequested != null;
  late final bool _hasNextEpisode = widget.onNextEpisodeRequested != null;

  void _closePlayer() async {
    // await FullScreenWindow.setFullScreen(false);
    Navigator.pop(NavigationService.navigatorKey.currentContext!);
  }

  void _goToPreviousEpisode() async {
    final newSettings = await widget.onPreviousEpisodeRequested?.call();
    if (newSettings != null) {
      setState(() {
        currentSettings = newSettings;
      });
    }
  }

  void _goToNextEpisode() async {
    final newSettings = await widget.onNextEpisodeRequested?.call();
    if (newSettings != null) {
      setState(() {
        currentSettings = newSettings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _closePlayer();
          }
        },
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(currentSettings.url)),
              // keepAlive: InAppWebViewKeepAlive(),
              // initialSettings: InAppWebViewSettings(),
              // onConsoleMessage: (controller, consoleMessage) {
              //   print(consoleMessage.message);
              // },
              // onCreateWindow: (controller, createWindowAction) async {
              //   return false;
              // },
              // onEnterFullscreen: (controller) {
              //   print('object');
              // },
              // onPermissionRequest: (controller, permissionRequest) async {
              //   print('object');
              //   return null;
              // },
              // preventGestureDelay: ,
              // shouldOverrideUrlLoading: (controller, navigationAction) async {
              //   // final uri = navigationAction.request.url;
              //   // if ([
              //   //   'vidsrc.xyz',
              //   //   'edgedeliverynetwork.com',
              //   //   'cloudnestra.com',
              //   // ].contains(uri?.host)) {
              //   //   print(navigationAction);
              //   //   return NavigationActionPolicy.ALLOW;
              //   // } else {
              //   //   print('URL cancelled ${uri.toString()}');
              //   //   return NavigationActionPolicy.CANCEL;
              //   // }
              //   return NavigationActionPolicy.ALLOW;
              // },
            ),
            Align(alignment: Alignment.topRight, child: IconButton(onPressed: _closePlayer, icon: const Icon(Icons.close))),

            if (_hasPreviousEpisode)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _goToPreviousEpisode,
                  icon: const Icon(Icons.arrow_circle_left),
                ),
              ),

            if (_hasNextEpisode)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _goToNextEpisode,
                  icon: const Icon(Icons.arrow_circle_right),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
