abstract interface class CountryNameResolver {
  Map<String, String> names(String countryCode);
}

final class CommonCountryNameResolver implements CountryNameResolver {
  const CommonCountryNameResolver();

  static const _translations = <String, Map<String, String>>{
    'BR': {'en': 'Brazil', 'es': 'Brasil', 'ca': 'Brasil'},
    'CA': {'en': 'Canada', 'es': 'Canadá', 'ca': 'Canadà'},
    'DE': {'en': 'Germany', 'es': 'Alemania', 'ca': 'Alemanya'},
    'ES': {'en': 'Spain', 'es': 'España', 'ca': 'Espanya'},
    'FR': {'en': 'France', 'es': 'Francia', 'ca': 'França'},
    'GB': {'en': 'United Kingdom', 'es': 'Reino Unido', 'ca': 'Regne Unit'},
    'IT': {'en': 'Italy', 'es': 'Italia', 'ca': 'Itàlia'},
    'NL': {'en': 'Netherlands', 'es': 'Países Bajos', 'ca': 'Països Baixos'},
    'US': {'en': 'United States', 'es': 'Estados Unidos', 'ca': 'Estats Units'},
  };

  @override
  Map<String, String> names(String countryCode) => Map.unmodifiable(
    _translations[countryCode] ??
        {'en': countryCode, 'es': countryCode, 'ca': countryCode},
  );
}

final class CountryMetadata {
  CountryMetadata({required this.code, required Map<String, String> names})
    : names = Map.unmodifiable(names),
      name = names['en'] ?? code,
      flag = countryFlag(code);

  final String code;
  final String name;
  final Map<String, String> names;
  final String flag;

  Map<String, Object?> toJson() => {
    'code': code,
    'name': name,
    'names': names,
    'flag': flag,
  };
}

CountryMetadata countryMetadata(String code, CountryNameResolver resolver) =>
    CountryMetadata(code: code, names: resolver.names(code));

String countryFlag(String code) {
  final normalized = code == 'UK' ? 'GB' : code;
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '';
  return String.fromCharCodes(
    normalized.codeUnits.map((unit) => unit + 127397),
  );
}
