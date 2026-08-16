import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/legal/domain/legal_document.dart';

/// Toolkit-agnostic renderer for a [LegalDocument].
///
/// Uses only base widgets and inherits its text color from the surrounding
/// [DefaultTextStyle] so it looks correct inside Material, macOS and Fluent
/// scaffolds alike.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final base = DefaultTextStyle.of(context).style;
    final muted = base.color?.withValues(alpha: 0.6);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          children: [
            Text(document.title.translate(locale), style: base.copyWith(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(document.lastUpdated.translate(locale), style: base.copyWith(fontSize: 13, color: muted)),
            const SizedBox(height: 24),
            for (final section in document.sections) ...[
              Text(section.heading.translate(locale), style: base.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(section.body.translate(locale), style: base.copyWith(fontSize: 15, height: 1.5)),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
