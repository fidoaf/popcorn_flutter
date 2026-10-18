import 'dart:ui';

final class LiveTvCountry {
  const LiveTvCountry({required this.code, required this.name, required this.flag, this.names = const {}});

  final String code;
  final String name;
  final String flag;
  final Map<String, String> names;

  String localizedName(Locale locale) => names[locale.languageCode] ?? name;

  factory LiveTvCountry.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    final flag = json['flag'];
    if (code is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(code) || name is! String || name.isEmpty || flag is! String) {
      throw const FormatException('Invalid live TV country');
    }
    final rawNames = json['names'];
    final names = <String, String>{};
    if (rawNames != null) {
      if (rawNames is! Map<String, dynamic>) throw const FormatException('Invalid live TV country names');
      for (final entry in rawNames.entries) {
        final value = entry.value;
        if (value is! String || value.isEmpty) throw const FormatException('Invalid live TV country name');
        names[entry.key] = value;
      }
    }
    return LiveTvCountry(code: code, name: name, flag: flag, names: Map.unmodifiable(names));
  }
}
