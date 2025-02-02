import 'package:popcorn_flutter/search/core/model/media_image.dart';
import 'package:popcorn_flutter/search/core/model/media_info.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_type.dart';

class OMDBItemVO extends MediaInfo {
  const OMDBItemVO._({required super.id, required super.name});

  static MediaInfo? fromData(Map<String, dynamic> data) {
    final id = data['imdbID'];
    final name = data['Title'];
    final type = OMDBMediaTypeVO.fromData(data['Type']);
    final posterUrl = data['Poster'];
    final poster = posterUrl == null ? null : MediaImage(url: posterUrl, type: MediaImageType.poster);
    switch (type) {
      case MediaType.movie:
        final String release = data['Year'];
        final dates = release.split('-');
        final int? releaseYear = int.tryParse(dates[0]);
        return MovieInfo(
          id: id,
          name: name,
          image: poster,
          releaseDate: releaseYear == null ? DateTime.now() : DateTime(releaseYear),
        );
      case MediaType.series:
        final String release = data['Year'];
        final dates = release.split(RegExp(r'\W')).where((st) => int.tryParse(st) != null).toList();
        final int? releaseYear = dates.isNotEmpty ? int.tryParse(dates[0]) : null;
        final int? endYear = dates.length > 1 ? int.tryParse(dates[1]) : null;
        return SeriesInfo(
          id: id,
          name: name,
          image: poster,
          startDate: releaseYear == null ? DateTime.now() : DateTime(releaseYear),
          endDate: endYear == null ? DateTime.now() : DateTime(endYear),
        );
      default:
    }
    return null;
  }

  @override
  String get dateExplanation => '';
}
