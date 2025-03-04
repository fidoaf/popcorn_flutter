import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_info_request.dart';
import 'package:popcorn_flutter/search/core/model/media_search.dart';
import 'package:popcorn_flutter/shared/core/use_case/use_case_interface.dart';

class DetailMediaItem implements UseCase {
  final IMediaSearcher _searcher;
  const DetailMediaItem({required IMediaSearcher searcher}) : _searcher = searcher;

  Future<MediaInfoResult> getDetails(MediaInfo info) async {
    try {
      final request = MediaInfoRequest.create(id: info.id);
      return _searcher.getMediaDetails(request);
    } catch (ex) {
      return MediaInfoResult(errors: [ex.toString()]);
    }
  }
}
