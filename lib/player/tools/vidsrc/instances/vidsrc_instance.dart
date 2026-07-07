import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_dev.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrc_xyz.dart';
import 'package:popcorn_flutter/player/tools/vidsrc/instances/vidsrcme_ru.dart';

abstract class VidSrcInstance {
  String get baseUrl;
}

enum VidsrcType {
  ru(VidsrcMeRu()),
  xyz(VidsrcXYZ()),
  dev(VidsrcDev());

  final VidSrcInstance instance;
  const VidsrcType(this.instance);

  static VidsrcType fromString(String value) => VidsrcType.values.firstWhere((vt) => vt.name == value, orElse: () => VidsrcType.values.first);
}
