import 'package:popcorn_flutter/app/core/service_locator.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/search/core/use_case/media_full_details.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

mixin DetailsMixin {
  final _details = DetailMediaItem(
    searcher: OMDBSearcher(
      secretKey: ServiceLocator.configuration.omdbKeySecret,
    ),
  );

   Future<MediaInfoResult> getDetails(MediaInfo info) {
    return _details.getDetails(info);
  }
}