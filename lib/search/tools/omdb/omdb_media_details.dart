import 'package:popcorn_flutter/details/core/model/media_full_details.dart';
import 'package:popcorn_flutter/search/core/model/media_image.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_type.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_shared.dart';

class OMDBDetailsVO extends MediaFullDetails {
  final String year;
  final String rated;
  final String released;
  final String runtime;
  final String director;
  final String writer;
  @override
  final String plot;
  final String language;
  final String country;
  final String awards;
  final String type;
  final String totalSeasons;

  const OMDBDetailsVO({
    required super.id,
    required super.name,
    required this.year,
    required this.rated,
    required this.released,
    required this.runtime,
    required this.director,
    required this.writer,
    required this.plot,
    required this.language,
    required this.country,
    required this.awards,
    required this.type,
    required this.totalSeasons,
  });

  static MediaFullDetails? fromData(Map<String, dynamic> data) {
    purgeData(data);

    final id = data['imdbID'];
    final name = data['Title'];
    final type = OMDBMediaTypeVO.fromData(data['Type']);
    final posterUrl = data['Poster'];
    final poster = posterUrl == null ? null : MediaImage(url: posterUrl, type: MediaImageType.poster);
    final plot = data['Plot'];

    final genreList = parseList(data, 'Genre');
    final actorList = parseList(data, 'Actors');

    final rated = data['Rated'];
    final released = data['Released'];
    final runtime = data['Runtime'];
    final director = data['Director'];
    final write = data['Writer'];
    final language = data['Language'];
    final country = data['Country'];
    // TODO: Ratings

    switch (type) {
      case MediaType.movie:
        final String release = data['Year'];
        final dates = release.split('-');
        final int? releaseYear = int.tryParse(dates[0]);
        return MediaFullDetails(
          id: id,
          name: name,
          image: poster,
          genres: genreList,
          casting: actorList,
          plot: plot,
          // releaseDate: releaseYear == null ? DateTime.now() : DateTime(releaseYear),
        );
      case MediaType.series:
        final String release = data['Year'];
        final dates = release.split(RegExp(r'\W')).where((st) => int.tryParse(st) != null).toList();
        final int? releaseYear = dates.isNotEmpty ? int.tryParse(dates[0]) : null;
        final int? endYear = dates.length > 1 ? int.tryParse(dates[1]) : null;
        return MediaFullDetails(
          id: id,
          name: name,
          image: poster,
          genres: genreList,
          casting: actorList,
          plot: plot,
          // startDate: releaseYear == null ? DateTime.now() : DateTime(releaseYear),
          // endDate: endYear == null ? DateTime.now() : DateTime(endYear),
        );
      default:
    }
    return null;
  }
}
