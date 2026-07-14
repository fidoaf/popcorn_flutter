import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';

class UnsupportedPlatformView extends StatelessWidget {
  const UnsupportedPlatformView({super.key});

  @override
  Widget build(BuildContext context) {
    final message = AppTranslations.unsupportedPlatform.translate(PlatformDispatcher.instance.locale);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 16, color: Color(0xFFFFFFFF), decoration: TextDecoration.none),
          ),
        ),
      ),
    );
  }
}
