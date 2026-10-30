/// A configurable section on the home screen.
enum HomeSection {
  movies('movies'),
  tvSeries('tv_series'),
  trailers('trailers'),
  liveTv('live_tv'),
  liveRadio('live_radio');

  const HomeSection(this.databaseValue);

  final String databaseValue;
}
