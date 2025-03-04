import 'package:popcorn_flutter/search/core/model/media_image.dart';
import 'package:popcorn_flutter/search/core/model/media_info_request.dart';
import 'package:popcorn_flutter/search/core/model/media_list.dart';
import 'package:popcorn_flutter/search/core/model/media_search_request.dart';

class MediaSearchResult {
  final MediaList list;
  final List<String>? errors;
  final int totalCount;
  final bool hasNextPage;
  const MediaSearchResult({this.list = const MediaList.empty(), this.totalCount = 0, this.hasNextPage = false, this.errors});

  bool get success => list.items.isNotEmpty;
}

class MediaInfoResult {
  final MediaFullDetails? details;
  final List<String>? errors;
  const MediaInfoResult({this.details, this.errors});

  bool get success => details != null;
}

class MediaFullDetails {
  final String id;
  final String name;
  final MediaImage? image;
  // final String year;
  // final String rated;
  // final String released;
  // final String runtime;
  // final String genre;
  // final String director;
  // final String writer;
  // final String actors;
  // final String plot;
  // final String language;
  // final String country;
  // final String awards;
  // final String type;
  // final String totalSeasons;

  const MediaFullDetails({
    required this.id,
    required this.name,
    this.image,
    // required this.year,
    // required this.rated,
    // required this.released,
    // required this.runtime,
    // required this.genre,
    // required this.director,
    // required this.writer,
    // required this.actors,
    // required this.plot,
    // required this.language,
    // required this.country,
    // required this.awards,
    // required this.type,
    // required this.totalSeasons,
  });
}

abstract class IMediaSearcher {
  Future<MediaSearchResult> searchMedia(MediaSearchRequest request);
  Future<MediaInfoResult> getMediaDetails(MediaInfoRequest request);
}
