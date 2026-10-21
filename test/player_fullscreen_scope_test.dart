import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/player/domain/fullscreen_controller.dart';
import 'package:popcorn_flutter/src/player/infrastructure/video_player/player_fullscreen_scope.dart';

class _FullscreenController implements FullscreenController {
  final calls = <bool>[];
  Future<void> Function(bool enabled)? onChange;

  @override
  Future<void> setFullscreen(bool enabled) async {
    calls.add(enabled);
    await onChange?.call(enabled);
  }
}

void main() {
  testWidgets('closing a fullscreen player restores the details page window', (tester) async {
    final platform = _FullscreenController();
    final navigator = GlobalKey<NavigatorState>();
    late FullscreenController player;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        navigatorKey: navigator,
        onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (context, animation, secondaryAnimation) => const Text('Details')),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => PlayerFullscreenScope(
            controller: platform,
            builder: (context, controller) {
              player = controller;
              return const Text('Player');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await player.setFullscreen(true);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(platform.calls, [true, false]);
    await player.setFullscreen(true);
    expect(platform.calls, [true, false], reason: 'Late callbacks must not re-enter fullscreen');
    expect(tester.takeException(), isNull);
  });

  for (final enterFullscreen in [false, true]) {
    testWidgets('closing ${enterFullscreen ? 'an already exited' : 'an inline'} player does not change the window', (tester) async {
      final platform = _FullscreenController();
      late FullscreenController player;
      await tester.pumpWidget(
        PlayerFullscreenScope(
          controller: platform,
          builder: (context, controller) {
            player = controller;
            return const SizedBox();
          },
        ),
      );
      if (enterFullscreen) {
        await player.setFullscreen(true);
        await player.setFullscreen(false);
      }
      await tester.pumpWidget(const SizedBox());
      expect(platform.calls, enterFullscreen ? [true, false] : isEmpty);
    });
  }

  testWidgets('closing waits for an in-flight fullscreen entry before restoring the window', (tester) async {
    final entered = Completer<void>();
    final platform = _FullscreenController()
      ..onChange = (enabled) async {
        if (enabled) await entered.future;
      };
    late FullscreenController player;
    await tester.pumpWidget(
      PlayerFullscreenScope(
        controller: platform,
        builder: (context, controller) {
          player = controller;
          return const SizedBox();
        },
      ),
    );
    final request = player.setFullscreen(true);
    await tester.pump();
    expect(platform.calls, [true]);
    await tester.pumpWidget(const SizedBox());
    expect(platform.calls, [true]);
    entered.complete();
    await request;
    await tester.pump();
    expect(platform.calls, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed fullscreen exit is logged and retried on close', (tester) async {
    final platform = _FullscreenController();
    final logs = <String?>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = originalDebugPrint);
    late FullscreenController player;
    await tester.pumpWidget(
      PlayerFullscreenScope(
        controller: platform,
        builder: (context, controller) {
          player = controller;
          return const SizedBox();
        },
      ),
    );
    await player.setFullscreen(true);
    platform.onChange = (_) async => throw StateError('exit failed');
    await expectLater(player.setFullscreen(false), throwsStateError);
    platform.onChange = null;
    await tester.pumpWidget(const SizedBox());
    debugPrint = originalDebugPrint;
    expect(platform.calls, [true, false, false]);
    expect(logs.single, contains('exit failed'));
    expect(tester.takeException(), isNull);
  });
}
