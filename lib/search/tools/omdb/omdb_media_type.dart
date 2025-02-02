import 'package:popcorn_flutter/search/core/model/media_type.dart';

extension OMDBMediaTypeVO on MediaType {
  static MediaType? fromData(String data) {
    switch (data.toLowerCase()) {
      case "series":
        return MediaType.series;
      case "movie":
        return MediaType.movie;
    }
    return null;
  }
}
