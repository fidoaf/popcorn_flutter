import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/app/view/macos/details_scaffold.dart';

void main() {
  testWidgets('details title expands while back and actions remain visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(800, 600);

    const title = 'A very long film title that should use the available space';
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MacosApp(navigatorKey: navigator, home: const MacosScaffold()),
    );
    navigator.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => MacosDetailsScaffold(
          title: title,
          actions: [
            CustomToolbarItem(
              inToolbarBuilder: (_) =>
                  const SizedBox(key: Key('logo'), width: 52, height: 30),
            ),
            CustomToolbarItem(
              inToolbarBuilder: (_) =>
                  const SizedBox(key: Key('profile'), width: 62, height: 30),
            ),
          ],
          children: [ContentArea(builder: (_, __) => const SizedBox())],
        ),
      ),
    );
    await tester.pumpAndSettle();

    double? previousWidth;
    for (final width in [420.0, 800.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 600);
      await tester.pumpAndSettle();
      final titleRect = tester.getRect(find.text(title));
      final backRect = tester.getRect(find.byType(MacosBackButton));
      final logoRect = tester.getRect(find.byKey(const Key('logo')));
      final profileRect = tester.getRect(find.byKey(const Key('profile')));
      expect(titleRect.left, greaterThanOrEqualTo(backRect.right));
      expect(titleRect.right, lessThanOrEqualTo(logoRect.left));
      expect(profileRect.right, lessThanOrEqualTo(width));
      if (previousWidth != null)
        expect(titleRect.width, greaterThan(previousWidth));
      previousWidth = titleRect.width;
      expect(tester.takeException(), isNull);
    }
    expect(
      tester.widget<Text>(find.text(title)).overflow,
      TextOverflow.ellipsis,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    debugDefaultTargetPlatformOverride = null;
  });
}
