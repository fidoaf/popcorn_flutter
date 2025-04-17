import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popcorn_flutter/player/core/model/media_player_settings.dart';
import 'package:popcorn_flutter/shared/core/model/navigation_service.dart';
import 'package:fullscreen_window/fullscreen_window.dart';

class FullScreenPlayer extends StatefulWidget {
  final MediaPlayerSettings playerSettings;
  final MediaPlayerSettings? Function()? onPreviousEpisodeRequested;
  final MediaPlayerSettings? Function()? onNextEpisodeRequested;
  const FullScreenPlayer({
    super.key,
    required this.playerSettings,
    this.onPreviousEpisodeRequested,
    this.onNextEpisodeRequested,
  });
  
  @override
  State<StatefulWidget> createState() => _FullScreenPlayerState();

}

class _FullScreenPlayerState extends State<FullScreenPlayer>{
  late MediaPlayerSettings currentSettings = widget.playerSettings;

  void _closePlayer() async {
    await FullScreenWindow.setFullScreen(false);
    Navigator.pop(NavigationService.navigatorKey.currentContext!);
  }

  void _goToPreviousEpisode() {
    final newSettings = widget.onPreviousEpisodeRequested?.call();
    if(newSettings != null){
      setState(() {
        currentSettings = newSettings;
      });
    }
  }

  void _goToNextEpisode() {
    final newSettings = widget.onNextEpisodeRequested?.call();
    if(newSettings != null){
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
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _closePlayer();
          }
        },
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(
                  currentSettings.url,
                ),
              ),
              keepAlive: InAppWebViewKeepAlive(),
              initialSettings: InAppWebViewSettings(),
              onConsoleMessage: (controller, consoleMessage) {
                print(consoleMessage.message);
              },
              onCreateWindow: (controller, createWindowAction) async {
                return false;
              },
              onEnterFullscreen: (controller) {
                print('object');
              },
              onPermissionRequest: (controller, permissionRequest) async {
                print('object');
                return null;
              },
              // preventGestureDelay: ,
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if ([
                  'vidsrc.xyz',
                  'edgedeliverynetwork.com',
                ].contains(uri?.host)) {
                  print(navigationAction);
                  return NavigationActionPolicy.ALLOW;
                } else {
                  print('URL cancelled ${uri.toString()}');
                  return NavigationActionPolicy.CANCEL;
                }
              },
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: _closePlayer,
                icon: const Icon(Icons.close),
              ),
            ),

            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _goToPreviousEpisode,
                icon: const Icon(Icons.arrow_circle_left),
              ),
            ),

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
