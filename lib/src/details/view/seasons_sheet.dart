import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_episode.dart';
import 'package:popcorn_flutter/src/search/domain/media_season.dart';

/// Loads the episodes for a given [MediaSeason] on demand.
typedef SeasonEpisodesLoader = Future<List<MediaEpisode>> Function(MediaSeason season);

/// Invoked when the play button of an [episode] within a [season] is tapped.
typedef EpisodePlayCallback = void Function(MediaSeason season, MediaEpisode episode);

/// Framework-agnostic content for the "seasons" bottom sheet.
///
/// Lists every [MediaSeason] with its poster, episode count, air year and
/// overview. When [episodesLoader] is provided, tapping a season expands it to
/// reveal the season's episodes (loaded lazily). Callers wrap this in the
/// platform's modal chrome (Material bottom sheet, Cupertino popup, etc.) and
/// provide the [titleStyle] so the header matches the surrounding typography.
class SeasonsSheetContent extends StatelessWidget {
  const SeasonsSheetContent({super.key, required this.seasons, this.titleStyle, this.subtitleColor, this.episodesLoader, this.onPlayEpisode});

  final List<MediaSeason> seasons;

  /// Style for the sheet header. Falls back to the ambient text style.
  final TextStyle? titleStyle;

  /// Color for the season subtitle line (episodes · year).
  final Color? subtitleColor;

  /// Loads the episodes for a tapped season. When `null`, seasons are not
  /// expandable.
  final SeasonEpisodesLoader? episodesLoader;

  /// Invoked when an episode's play button is tapped. When `null`, no play
  /// button is shown.
  final EpisodePlayCallback? onPlayEpisode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0x33808080), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(DetailsTranslations.seasonsTitle.trOf(context), style: titleStyle),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: seasons.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _SeasonTile(season: seasons[index], subtitleColor: subtitleColor, episodesLoader: episodesLoader, onPlayEpisode: onPlayEpisode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonTile extends StatefulWidget {
  const _SeasonTile({required this.season, this.subtitleColor, this.episodesLoader, this.onPlayEpisode});

  final MediaSeason season;
  final Color? subtitleColor;
  final SeasonEpisodesLoader? episodesLoader;
  final EpisodePlayCallback? onPlayEpisode;

  @override
  State<_SeasonTile> createState() => _SeasonTileState();
}

class _SeasonTileState extends State<_SeasonTile> {
  static const double _posterWidth = 64;
  static const double _posterHeight = 96;

  bool _expanded = false;
  Future<List<MediaEpisode>>? _episodes;

  bool get _expandable => widget.episodesLoader != null;

  void _toggle() {
    if (!_expandable) return;
    setState(() {
      _expanded = !_expanded;
      _episodes ??= widget.episodesLoader!(widget.season);
    });
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.season.overview.trim();
    final subtitle = _subtitle(context);
    final subtitleColor = widget.subtitleColor ?? const Color(0xFF808080);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _poster(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.season.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor))],
              if (overview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(overview, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        if (_expandable) ...[const SizedBox(width: 8), _Chevron(expanded: _expanded, color: subtitleColor)],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40FFFFFF)),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 1, offset: Offset(0, -1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _expandable ? _toggle : null, child: header),
          if (_expanded) Padding(padding: const EdgeInsets.only(top: 12), child: _episodesSection(context, subtitleColor)),
        ],
      ),
    );
  }

  Widget _episodesSection(BuildContext context, Color subtitleColor) {
    return FutureBuilder<List<MediaEpisode>>(
      future: _episodes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: _Spinner(color: subtitleColor)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(DetailsTranslations.episodesError.trOf(context), style: TextStyle(fontSize: 12, color: subtitleColor)),
          );
        }
        final episodes = snapshot.data ?? const <MediaEpisode>[];
        if (episodes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(DetailsTranslations.noEpisodes.trOf(context), style: TextStyle(fontSize: 12, color: subtitleColor)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final episode in episodes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EpisodeTile(
                  episode: episode,
                  subtitleColor: subtitleColor,
                  onPlay: widget.onPlayEpisode == null ? null : () => widget.onPlayEpisode!(widget.season, episode),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _poster() {
    final url = widget.season.posterUrl;
    if (url == null) {
      return _imagePlaceholder(_posterWidth, _posterHeight);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url.toString(),
        width: _posterWidth,
        height: _posterHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _imagePlaceholder(_posterWidth, _posterHeight),
      ),
    );
  }

  String? _subtitle(BuildContext context) {
    final parts = <String>[];
    final episodes = widget.season.episodeCount;
    if (episodes != null && episodes > 0) {
      final label = (episodes == 1 ? DetailsTranslations.episode : DetailsTranslations.episodes).trOf(context);
      parts.add('$episodes $label');
    }
    final year = widget.season.airDate?.year;
    if (year != null) parts.add('$year');
    final rating = widget.season.voteAverage;
    if (rating != null && rating > 0) {
      parts.add('\u2605 ${rating.toStringAsFixed(1)}');
    }
    return parts.isEmpty ? null : parts.join(' \u00b7 ');
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.subtitleColor, this.onPlay});

  final MediaEpisode episode;
  final Color subtitleColor;
  final VoidCallback? onPlay;

  static const double _stillWidth = 96;
  static const double _stillHeight = 54;

  @override
  Widget build(BuildContext context) {
    final overview = episode.overview.trim();
    final subtitle = _subtitle();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _still(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${episode.episodeNumber}. ${episode.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor))],
              if (overview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(overview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        if (onPlay != null) ...[const SizedBox(width: 8), _PlayButton(onTap: onPlay!)],
      ],
    );
  }

  Widget _still() {
    final url = episode.stillUrl;
    if (url == null) {
      return _imagePlaceholder(_stillWidth, _stillHeight);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url.toString(),
        width: _stillWidth,
        height: _stillHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => _imagePlaceholder(_stillWidth, _stillHeight),
      ),
    );
  }

  String? _subtitle() {
    final parts = <String>[];
    final runtime = episode.runtime;
    if (runtime != null && runtime > Duration.zero) {
      parts.add('${runtime.inMinutes}m');
    }
    final year = episode.airDate?.year;
    if (year != null) parts.add('$year');
    final rating = episode.voteAverage;
    if (rating != null && rating > 0) {
      parts.add('\u2605 ${rating.toStringAsFixed(1)}');
    }
    return parts.isEmpty ? null : parts.join(' \u00b7 ');
  }
}

Widget _imagePlaceholder(double width, double height) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: const Color(0x22808080), borderRadius: BorderRadius.circular(6)),
  );
}

/// A circular play button, drawn on the widgets layer so this sheet stays
/// independent of Material/Cupertino.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(size: const Size.square(_size), painter: _PlayPainter(const Color(0xFFE50914))),
    );
  }
}

class _PlayPainter extends CustomPainter {
  _PlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = color);

    final side = size.width * 0.34;
    final height = side * 0.866;
    final path = Path()
      ..moveTo(center.dx - height / 3, center.dy - side / 2)
      ..lineTo(center.dx - height / 3, center.dy + side / 2)
      ..lineTo(center.dx + (height * 2 / 3), center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _PlayPainter oldDelegate) => oldDelegate.color != color;
}

/// A standard expand/collapse chevron, backed by an SVG asset so icons can be
/// managed as files (and swapped per platform) instead of hand-drawn code.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded, this.color});

  final bool expanded;
  final Color? color;

  static const double _size = 20;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      expanded ? 'assets/icons/chevron_up.svg' : 'assets/icons/chevron_down.svg',
      width: _size,
      height: _size,
      colorFilter: ColorFilter.mode(color ?? const Color(0xFF808080), BlendMode.srcIn),
    );
  }
}

/// A minimal, framework-agnostic loading spinner built on the widgets layer so
/// this sheet stays independent of Material/Cupertino.
class _Spinner extends StatefulWidget {
  const _Spinner({this.color});

  final Color? color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  static const double _size = 22;

  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(size: const Size.square(_size), painter: _SpinnerPainter(widget.color ?? const Color(0xFF808080))),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 8;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.25);
    canvas.drawArc(rect, 0, 6.283185, false, paint);
    paint.color = color;
    canvas.drawArc(rect, -1.5708, 1.7, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) => oldDelegate.color != color;
}
