import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// A TMDB person profile and their most popular combined credits.
final class MediaPerson {
  const MediaPerson({
    required this.id,
    required this.name,
    this.biography = '',
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.knownForDepartment,
    this.profileUrl,
    this.knownFor = const [],
  });

  final int id;
  final String name;
  final String biography;
  final DateTime? birthday;
  final DateTime? deathday;
  final String? placeOfBirth;
  final String? knownForDepartment;
  final Uri? profileUrl;
  final List<PersonCredit> knownFor;
}

/// A movie or series credit in a person's combined filmography.
final class PersonCredit {
  const PersonCredit({required this.item, required this.type, this.role, this.popularity = 0});

  final MediaItem item;
  final MediaType type;
  final String? role;
  final double popularity;
}
