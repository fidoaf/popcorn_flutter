@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/domain/media_source.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/platform_video_player_web.dart';
import 'package:web/web.dart' as web;

@JS('Object.defineProperty')
external JSObject _defineProperty(JSObject target, JSString key, JSObject descriptor);

@JS('Reflect.deleteProperty')
external JSBoolean _deleteProperty(JSObject target, JSString key);

void main() {
  for (final fullscreen in [false, true]) {
    testWidgets('Back ${fullscreen ? 'exits fullscreen' : 'does not request fullscreen exit for an inline player'}', (tester) async {
      var exits = 0;
      _defineProperty(
        web.document,
        'fullscreenElement'.toJS,
        {'configurable': true, 'value': fullscreen ? web.document.documentElement : null}.jsify() as JSObject,
      );
      web.document.setProperty(
        'exitFullscreen'.toJS,
        (() {
          exits++;
          return Future<JSAny?>.value().toJS;
        }).toJS,
      );
      addTearDown(() {
        _deleteProperty(web.document, 'fullscreenElement'.toJS);
        _deleteProperty(web.document, 'exitFullscreen'.toJS);
      });
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          navigatorKey: navigator,
          onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (context, animation, secondaryAnimation) => const Text('Home')),
        ),
      );
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => WebVideoPlayer(
            source: MediaSource(url: Uri.parse('https://player.invalid/fullscreen-test-$fullscreen'), data: '<html><body>Video</body></html>'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HtmlElementView), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(exits, fullscreen ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
}