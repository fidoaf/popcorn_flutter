import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/locale/domain/translation.dart';

extension TranslationContext on Translation {
  String trOf(BuildContext context) => translate(Localizations.localeOf(context));
}
