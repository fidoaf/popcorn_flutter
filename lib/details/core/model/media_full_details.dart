
import 'package:popcorn_flutter/search/core/model/media_image.dart';

class MediaFullDetails {
  final String id;
  final String name;
  final MediaImage? image;
  // final String year;
  // final String rated;
  // final String released;
  // final String runtime;
  final List<String> genres;
  // final String director;
  // final String writer;
  final List<String> casting;
  final String plot;
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
    this.genres = const [],
    // required this.director,
    // required this.writer,
    this.casting = const [],
    this.plot = "",
    // required this.language,
    // required this.country,
    // required this.awards,
    // required this.type,
    // required this.totalSeasons,
  });
}
