abstract class HistoryMediaInfo {
}

class HistorySeriesInfo extends HistoryMediaInfo{
  int season;
  int episode;
  HistorySeriesInfo({required this.season, required this.episode});
}

class HistoryMovieInfo extends HistoryMediaInfo {
}