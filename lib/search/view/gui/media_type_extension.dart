import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';

extension MediaTypeExtension on MediaType {
  Widget get icon {
    switch (this) {
      case MediaType.movie:
        return const FaIcon(FontAwesomeIcons.film);
      case MediaType.series:
        return const FaIcon(FontAwesomeIcons.tv);
    }
  }
}
