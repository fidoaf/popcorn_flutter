class MediaInfoRequest {
  final String id;
  MediaInfoRequest._({required this.id});

  static MediaInfoRequest create({required String id}) {
    if (id.isEmpty) throw Exception('ID is required');
    return MediaInfoRequest._(id: id);
  }
}
