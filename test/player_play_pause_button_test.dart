import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/view/player_play_pause_button.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    for (final prominent in [false, true]) {
      testWidgets('$platform ${prominent ? 'center' : 'toolbar'} playback button is hidden and inert during loading', (tester) async {
        var pressed = 0;
        Future<void> render({required bool loading, bool playing = false}) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: PlayerPlayPauseButton(loading: loading, playing: playing, prominent: prominent, onPressed: () => pressed++),
              ),
            ),
          ),
        );
        await render(loading: false);
        final button = find.byType(PlayerPlayPauseButton);
        final size = tester.getSize(button);
        expect(find.byIcon(Icons.play_arrow).hitTestable(), findsOneWidget);
        await tester.tap(find.byIcon(Icons.play_arrow));
        expect(pressed, 1);
        for (final playing in [false, true]) {
          await render(loading: true, playing: playing);
          expect(tester.getSize(button), size);
          expect(tester.widget<Visibility>(find.byType(Visibility)).visible, isFalse);
          expect(find.byIcon(playing ? Icons.pause : Icons.play_arrow).hitTestable(), findsNothing);
          await tester.tapAt(tester.getCenter(button));
          expect(pressed, 1);
        }
        await render(loading: false, playing: true);
        expect(find.byIcon(Icons.pause).hitTestable(), findsOneWidget);
        await tester.tap(find.byIcon(Icons.pause));
        expect(pressed, 2);
      });
    }
  }
}
