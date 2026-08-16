import 'package:popcorn_flutter/src/locale/domain/translation.dart';

/// A localized legal document (e.g. privacy policy, terms of service) made up of
/// a title, a "last updated" line and an ordered list of headed sections.
class LegalDocument {
  const LegalDocument({required this.title, required this.lastUpdated, required this.sections});

  final Translation title;
  final Translation lastUpdated;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final Translation heading;
  final Translation body;
}
