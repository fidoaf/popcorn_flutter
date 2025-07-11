abstract class HistoryMediaInfo {
  HistoryMediaInfo? get previous;
  HistoryMediaInfo? get next;
}

class HistorySeriesInfo extends HistoryMediaInfo {
  int season;
  int episode;
  HistorySeriesInfo({required this.season, required this.episode});

  @override
  HistoryMediaInfo? get previous =>
      HistorySeriesInfo(season: season, episode: episode - 1);

  @override
  HistoryMediaInfo? get next =>
      HistorySeriesInfo(season: season, episode: episode + 1);
}

class HistoryMovieInfo extends HistoryMediaInfo {
  @override
  HistoryMediaInfo? get previous => null;
  @override
  HistoryMediaInfo? get next => null;
}
