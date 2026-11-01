import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// A details page whose title expands with the window without hiding actions.
class MacosDetailsScaffold extends StatelessWidget {
  const MacosDetailsScaffold({
    super.key,
    required this.title,
    required this.actions,
    required this.children,
  });

  final String title;
  final List<ToolbarItem> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => MacosScaffold(
      toolBar: ToolBar(
        // Reserve room for window controls, the back button and toolbar actions.
        titleWidth: math.max(0, constraints.maxWidth - 220),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      children: children,
    ),
  );
}
