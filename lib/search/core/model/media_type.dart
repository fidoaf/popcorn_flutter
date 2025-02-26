import 'package:collection/collection.dart';

enum MediaType {
  movie,
  series;

  static MediaType? fromString(String text) => MediaType.values.firstWhereOrNull((mt) => mt.name == text);
}
