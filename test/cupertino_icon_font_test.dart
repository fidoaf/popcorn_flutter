import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cupertino icon font is bundled', (tester) async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    final family =
        'packages/${CupertinoIcons.search.fontPackage}/${CupertinoIcons.search.fontFamily}';
    final font = manifest.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['family'] == family,
    );
    final assets = (font['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(assets, isNotEmpty);
    final fontData = await rootBundle.load(assets.first['asset'] as String);
    expect(fontData.lengthInBytes, greaterThan(0));
  });
}
