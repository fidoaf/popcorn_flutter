import 'package:flutter/material.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';

extension MediaTypeExtension on MediaType {
  Widget get icon {
    switch (this) {
      case MediaType.movie:
        return const Icon(Icons.movie);
      case MediaType.series:
        return const Icon(Icons.tv);
    }
  }
}
