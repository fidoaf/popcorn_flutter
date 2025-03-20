abstract class ApplicationConfiguration {
  String? getString(String key);

  int? getInt(String key);

  String get omdbKeySecret => getString('omdbKeySecret') ?? '';
  String get browser => getString('browser') ?? '';
  String get vidsrcInstance => getString('vidsrcInstance') ?? '';
}
