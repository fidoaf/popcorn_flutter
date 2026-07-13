import 'package:flutter/material.dart';
import 'package:popcorn_flutter/page/domain/view_page.dart';

class MaterialViewPage implements ViewPage {
  final Widget Function() _contentGenerator;
  const MaterialViewPage(this._contentGenerator);

  Widget get content => _contentGenerator();
}
