import 'dart:math';

import 'package:flutter/material.dart';

/// Public-domain classic movie posters bundled under `assets/posters/`
/// (see `assets/posters/CREDITS.txt`). Shared by the landing and login screens.
const List<String> kClassicPosters = [
  'assets/posters/angel_and_the_badman.jpg',
  'assets/posters/battleship_potemkin_1925.jpg',
  'assets/posters/beat_the_devil_1953.jpg',
  'assets/posters/caligari_1920.jpg',
  'assets/posters/carnival_of_souls_1962.jpg',
  'assets/posters/charade_1963.jpg',
  'assets/posters/detour_1945.jpg',
  'assets/posters/doa_1949.jpg',
  'assets/posters/frankenstein_1931.jpg',
  'assets/posters/gold_rush_1925.jpg',
  'assets/posters/his_girl_friday_1940.jpg',
  'assets/posters/intolerance_1916.jpg',
  'assets/posters/meet_john_doe_1941.jpg',
  'assets/posters/metropolis_1927.jpg',
  'assets/posters/nanook_of_the_north_1922.jpg',
  'assets/posters/night_living_dead_1968.jpg',
  'assets/posters/nosferatu_1922.png',
  'assets/posters/phantom_opera_1925.jpg',
  'assets/posters/plan9_1959.jpg',
  'assets/posters/reefer_madness_1936.jpg',
  'assets/posters/safety_last_1923.jpg',
  'assets/posters/santa_claus_martians.jpg',
  'assets/posters/steamboat_bill_jr_1928.jpg',
  'assets/posters/suddenly_1954.jpg',
  'assets/posters/sunrise_1927.jpg',
  'assets/posters/the_general_1926.png',
  'assets/posters/the_great_train_robbery.jpg',
  'assets/posters/the_jazz_singer_1927.jpg',
  'assets/posters/the_kid_1921.jpg',
  'assets/posters/the_kid_brother_1927.jpg',
  'assets/posters/the_lost_world_1925.jpg',
  'assets/posters/the_stranger_1946.jpg',
  'assets/posters/the_ten_commandments_1923.jpg',
  'assets/posters/the_thief_of_bagdad_1924.jpg',
  'assets/posters/wings_1927.jpg',
];

/// Returns a freshly shuffled copy of [pool], optionally limited to [count].
List<String> _shuffled(List<String> pool, {int? count}) {
  final list = List<String>.of(pool)..shuffle(Random());
  if (count != null && count < list.length) return list.sublist(0, count);
  return list;
}

/// A 3-column grid of poster tiles (used in the landing hero). Randomized once
/// per instance so each visit shows a different selection.
class PosterCollage extends StatefulWidget {
  const PosterCollage({super.key, this.pool = kClassicPosters, this.count = 9});

  final List<String> pool;
  final int count;

  @override
  State<PosterCollage> createState() => _PosterCollageState();
}

class _PosterCollageState extends State<PosterCollage> {
  late final List<String> _posters = _shuffled(widget.pool, count: widget.count);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _posters.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2 / 3),
      itemBuilder: (context, index) => _PosterTile(asset: _posters[index]),
    );
  }
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Image.asset(asset, fit: BoxFit.cover),
      ),
    );
  }
}

/// Full-bleed, dimmed poster wall used as a cinematic backdrop behind content.
/// The tiling order is randomized once per instance.
class PosterBackdrop extends StatefulWidget {
  const PosterBackdrop({super.key, this.pool = kClassicPosters, this.tileWidth = 150});

  final List<String> pool;
  final double tileWidth;

  @override
  State<PosterBackdrop> createState() => _PosterBackdropState();
}

class _PosterBackdropState extends State<PosterBackdrop> {
  final Random _random = Random();
  final List<String> _tiles = [];

  // Grows [_tiles] to at least [count] by appending fresh shuffles of the whole
  // pool, so no poster repeats until the entire pool has been shown.
  void _ensure(int count) {
    while (_tiles.length < count) {
      final batch = List<String>.of(widget.pool)..shuffle(_random);
      if (_tiles.isNotEmpty && batch.length > 1 && batch.first == _tiles.last) {
        final swap = 1 + _random.nextInt(batch.length - 1);
        final tmp = batch[0];
        batch[0] = batch[swap];
        batch[swap] = tmp;
      }
      _tiles.addAll(batch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tileWidth = widget.tileWidth;
    final tileHeight = tileWidth * 3 / 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / tileWidth).ceil() + 1;
        final rows = (constraints.maxHeight / tileHeight).ceil() + 1;
        final count = columns * rows;
        _ensure(count);
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: columns * tileWidth,
                maxHeight: rows * tileHeight,
                child: Wrap(
                  children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: Image.asset(_tiles[i], fit: BoxFit.cover),
                      ),
                  ],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xE60F1014), Color(0xF21C1030)]),
              ),
            ),
          ],
        );
      },
    );
  }
}
