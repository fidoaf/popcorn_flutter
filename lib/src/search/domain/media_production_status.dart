/// The production lifecycle state of a movie or TV series, as reported by the
/// catalogue's `status` field.
enum MediaProductionStatus {
  returningSeries,
  planned,
  inProduction,
  postProduction,
  ended,
  canceled,
  released,
  rumored,
  unknown;

  /// Maps a raw TMDB `status` string to a [MediaProductionStatus].
  static MediaProductionStatus fromTmdb(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'returning series':
        return MediaProductionStatus.returningSeries;
      case 'planned':
        return MediaProductionStatus.planned;
      case 'in production':
        return MediaProductionStatus.inProduction;
      case 'post production':
        return MediaProductionStatus.postProduction;
      case 'ended':
        return MediaProductionStatus.ended;
      case 'canceled':
      case 'cancelled':
        return MediaProductionStatus.canceled;
      case 'released':
        return MediaProductionStatus.released;
      case 'rumored':
        return MediaProductionStatus.rumored;
      default:
        return MediaProductionStatus.unknown;
    }
  }
}
