import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';

class VidsrcDev implements VidSrcInstance {
  static const String _urlPath = 'https://vidsrc.dev/embed';

  const VidsrcDev();

  @override
  String get baseUrl => _urlPath;
}
