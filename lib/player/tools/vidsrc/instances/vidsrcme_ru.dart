import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';

class VidsrcMeRu implements VidSrcInstance {
  static const String _urlPath = 'https://vidsrcme.ru/embed';

  const VidsrcMeRu();

  @override
  String get baseUrl => _urlPath;
}
