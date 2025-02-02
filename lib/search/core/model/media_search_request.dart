import 'package:popcorn_flutter/search/core/model/media_type.dart';

class MediaSearchRequest {
  final String terms;
  final MediaType? type;
  MediaSearchRequest._({required this.terms, this.type});

  static MediaSearchRequest create({String? terms, MediaType? type}) {
    if (terms == null || terms.isEmpty) throw Exception('Search terms is required');
    return MediaSearchRequest._(terms: terms);
  }
}
