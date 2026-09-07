import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// Friendly full-screen page shown when the app cannot finish starting up
/// (e.g. its configuration could not be loaded). Uses only base widgets so it
/// renders under any app shell (Material, Cupertino, macOS, Fluent, Widgets).
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppTranslations.maintenanceTitle.trOf(context),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF), decoration: TextDecoration.none),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.maintenanceMessage.trOf(context),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFFB0B0B0), decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }
}
