import 'package:popcorn_flutter/search/core/model/media_type.dart';

class MediaSearchRequest {
  final String terms;
  final MediaType? type;
  final int? page;
  MediaSearchRequest._({required this.terms, this.type, this.page});

  static MediaSearchRequest create({String? terms, MediaType? type, int? page}) {
    if (terms == null || terms.isEmpty) throw Exception('Search terms is required');
    return MediaSearchRequest._(terms: terms, page: page, type: type);
  }
}
