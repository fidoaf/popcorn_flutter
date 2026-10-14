import 'package:flutter/widgets.dart';

double playerOverlayTopInset(BuildContext context) => MediaQuery.sizeOf(context).width < 600 ? 56 : 0;
