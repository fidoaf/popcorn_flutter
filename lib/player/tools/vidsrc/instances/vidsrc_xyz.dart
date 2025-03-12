import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_instance.dart';

class VidsrcXYZ implements VidSrcInstance {
  static const String _urlPath = 'https://vidsrc.xyz/embed';

  const VidsrcXYZ();

  @override
  String get baseUrl => _urlPath;
}
