import 'package:popcorn_flutter/search/core/model/media_image.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';

class MediaInfo {
  final String id;
  final String name;
  final MediaType? type;
  final MediaImage? image;
  const MediaInfo({required this.id, required this.name, this.type, this.image});

  @override
  String toString() {
    return '[$name ($dateExplanation)]';
  }

  String get dateExplanation => '';

  static MediaInfo fromJson(Map<String, dynamic> data) {
    return MediaInfo(id: data['id'], name: data['name'], type: MediaType.fromString(data['type']), image: MediaImage.fromJson(data['image']));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type?.name,
      'image': image?.toJson(),
    };
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    return other is MediaInfo && hashCode == other.hashCode;
  }
}

class MovieInfo extends MediaInfo {
  final DateTime releaseDate;
  const MovieInfo({required super.id, required super.name, super.image, required this.releaseDate}) : super(type: MediaType.movie);

  @override
  String get dateExplanation => '${releaseDate.year}';
}

class SeriesInfo extends MediaInfo {
  final DateTime startDate;
  final DateTime? endDate;
  const SeriesInfo({required super.id, required super.name, super.image, required this.startDate, this.endDate}) : super(type: MediaType.series);

  @override
  String get dateExplanation {
    return '${startDate.year} - ${endDate?.year ?? '???'}';
  }
}
