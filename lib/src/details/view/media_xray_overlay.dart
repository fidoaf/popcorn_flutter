import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/shared_details_builders.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/cast_member.dart';
import 'package:popcorn_flutter/src/search/domain/media_details.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';

/// Wraps a video player with an X-Ray style overlay (à la Prime Video): a small
/// pill button anchored at the top that, when tapped, slides down a panel
/// showing the title's cast and other info.
///
/// The extended [MediaDetails] (director, cast, runtime/seasons) are fetched
/// lazily via [detailsLoader] the first time the panel is opened, so the
/// network call is only made if the viewer actually asks for it.
class MediaXRayOverlay extends StatefulWidget {
  const MediaXRayOverlay({super.key, required this.child, required this.item, required this.detailsLoader});

  /// The player (or any content) the overlay is layered on top of.
  final Widget child;

  /// The title being watched, providing the poster, name, year and rating.
  final MediaItem item;

  /// Lazily resolves the extended details when the panel is first opened.
  final Future<MediaDetails> Function() detailsLoader;

  @override
  State<MediaXRayOverlay> createState() => _MediaXRayOverlayState();
}

class _MediaXRayOverlayState extends State<MediaXRayOverlay> {
  bool _open = false;
  Future<MediaDetails>? _details;

  void _toggle() {
    setState(() {
      _open = !_open;
      _details ??= widget.detailsLoader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Toggle pill, hidden while the panel is open.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: IgnorePointer(
              ignoring: _open,
              child: AnimatedOpacity(
                opacity: _open ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _XRayButton(onPressed: _toggle),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Scrim + sliding info panel.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_open,
            child: AnimatedOpacity(
              opacity: _open ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggle,
                      child: const ColoredBox(color: Colors.black54),
                    ),
                  ),
                  SafeArea(
                    child: AnimatedSlide(
                      offset: _open ? Offset.zero : const Offset(0, -1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _XRayPanel(item: widget.item, details: _details, onClose: _toggle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _XRayButton extends StatelessWidget {
  const _XRayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_outlined, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                DetailsTranslations.castAndInfo.trOf(context),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XRayPanel extends StatelessWidget {
  const _XRayPanel({required this.item, required this.details, required this.onClose});

  final MediaItem item;
  final Future<MediaDetails>? details;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: media.size.height * 0.7),
        child: Material(
          color: const Color(0xF01A1A1A),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DetailsTranslations.castAndInfo.trOf(context),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: DetailsTranslations.close.trOf(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(item: item, details: details),
                      if (item.overview.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(item.overview, style: const TextStyle(color: Colors.white70, height: 1.4)),
                      ],
                      _Credits(details: details),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item, required this.details});

  final MediaItem item;
  final Future<MediaDetails>? details;

  @override
  Widget build(BuildContext context) {
    final poster = item.posterUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 80,
            height: 120,
            child: poster == null
                ? const ColoredBox(
                    color: Colors.white10,
                    child: Icon(Icons.movie_outlined, color: Colors.white38),
                  )
                : Image.network(
                    poster.toString(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const ColoredBox(
                      color: Colors.white10,
                      child: Icon(Icons.movie_outlined, color: Colors.white38),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _MetaLine(item: item),
              MetadataLineBuilder(
                details: details,
                builder: (context, text, data) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(text, style: const TextStyle(color: Colors.white60)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final year = item.releaseDate?.year;
    final rating = item.voteAverage;
    return Row(
      children: [
        if (rating != null && rating > 0) ...[
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70)),
          if (year != null) const SizedBox(width: 12),
        ],
        if (year != null) Text('$year', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.details});

  final Future<MediaDetails>? details;

  @override
  Widget build(BuildContext context) {
    if (details == null) return const SizedBox.shrink();
    return FutureBuilder<MediaDetails>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.only(top: 16), child: _CastList(members: null));
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final director = data.director;
        final members = data.castMembers;
        if (director == null && members.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (director != null) ...[_CreditRow(label: DetailsTranslations.director.trOf(context), value: director), const SizedBox(height: 16)],
              if (members.isNotEmpty) ...[
                Text(
                  DetailsTranslations.cast.trOf(context),
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _CastList(members: members),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal row of cast cards. A `null` [members] renders placeholder cards
/// while the details load.
class _CastList extends StatelessWidget {
  const _CastList({required this.members});

  final List<CastMember>? members;

  @override
  Widget build(BuildContext context) {
    final items = members;
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items?.length ?? 4,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _CastCard(member: items?[index]),
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  /// The cast member, or `null` to render a loading placeholder.
  final CastMember? member;

  @override
  Widget build(BuildContext context) {
    final profile = member?.profileUrl;
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 120,
              height: 150,
              child: profile == null
                  ? const ColoredBox(
                      color: Colors.white10,
                      child: Icon(Icons.person, color: Colors.white38, size: 40),
                    )
                  : Image.network(
                      profile.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const ColoredBox(
                        color: Colors.white10,
                        child: Icon(Icons.person, color: Colors.white38, size: 40),
                      ),
                    ),
            ),
          ),
          if (member != null) ...[
            const SizedBox(height: 8),
            Text(
              member!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            if (member!.character != null)
              Text(
                member!.character!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, height: 1.4)),
      ],
    );
  }
}
