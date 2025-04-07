abstract class ApplicationConfiguration {
  String? getString(String key);

  int? getInt(String key);

  String get omdbKeySecret => getString('omdb.keySecret') ?? '';
  String get browser => getString('browser') ?? '';
  String get vidsrcInstance => getString('vidsrc.instance') ?? '';
}
