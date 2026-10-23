import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/details/view/media_xray_overlay.dart';
import 'package:popcorn_flutter/src/player/view/player_close_button.dart';
import 'package:popcorn_flutter/src/player/view/player_controls_scope.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';

double _opacity(WidgetTester tester, Finder control) => tester
    .widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.ancestor(of: control, matching: find.byType(PlayerOverlayControls)).first,
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets('Cast, close and back hide together after three seconds and return on mouse movement', (tester) async {
    late PlayerControlsController controls;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerControlsScope(
          child: Builder(
            builder: (context) {
              controls = PlayerControlsScope.controllerOf(context)!;
              return Stack(
                fit: StackFit.expand,
                children: [
                  MediaXRayOverlay(
                    item: const MediaItem(id: 1, title: 'Movie', overview: ''),
                    detailsLoader: () async => const MediaDetails(),
                    child: const ColoredBox(color: Colors.black),
                  ),
                  Positioned(top: 12, right: 12, child: PlayerCloseButton(onClose: () => closed = true)),
                  const Positioned(top: 12, left: 12, child: PlayerOverlayControls(child: Text('Back'))),
                ],
              );
            },
          ),
        ),
      ),
    );
    final cast = find.byIcon(Icons.people_alt_outlined);
    final close = find.descendant(of: find.byType(PlayerCloseButton), matching: find.byType(IconButton));
    final back = find.text('Back');
    controls.playing = true;
    await tester.pump(const Duration(milliseconds: 2999));
    for (final control in [cast, close, back]) {
      expect(_opacity(tester, control), 1);
    }
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    for (final control in [cast, close, back]) {
      expect(_opacity(tester, control), 0);
      expect(control.hitTestable(), findsNothing);
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await tester.pump();
    await mouse.moveTo(const Offset(401, 400));
    expect(controls.value, isTrue);
    await tester.pumpAndSettle();
    for (final control in [cast, close, back]) {
      expect(_opacity(tester, control), 1);
    }
    await tester.tap(close);
    expect(closed, isTrue);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity resets the timer, pause keeps controls visible, and resume restarts hiding', (tester) async {
    final controls = PlayerControlsController();
    addTearDown(controls.dispose);
    controls.playing = true;
    await tester.pump(const Duration(seconds: 2));
    controls.show();
    await tester.pump(const Duration(seconds: 2));
    expect(controls.value, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(controls.value, isFalse);
    controls.playing = false;
    await tester.pump(const Duration(seconds: 10));
    expect(controls.value, isTrue);
    controls.playing = true;
    await tester.pump(const Duration(seconds: 3));
    expect(controls.value, isFalse);
  });

  testWidgets('keyboard and touch reveal hidden overlays', (tester) async {
    late PlayerControlsController controls;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerControlsScope(
          child: Builder(
            builder: (context) {
              controls = PlayerControlsScope.controllerOf(context)!;
              return const Focus(
                autofocus: true,
                child: Center(child: PlayerOverlayControls(child: Text('Overlay'))),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    controls.playing = true;
    await tester.pump(const Duration(seconds: 3));
    expect(controls.value, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controls.value, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(controls.value, isFalse);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(controls.value, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disabled scopes preserve overlays without auto hiding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerControlsScope(
          enabled: false,
          child: Builder(
            builder: (context) {
              expect(PlayerControlsScope.controllerOf(context), isNull);
              return const PlayerOverlayControls(child: Text('Overlay'));
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(_opacity(tester, find.text('Overlay')), 1);
    expect(find.text('Overlay').hitTestable(), findsOneWidget);
  });
}
