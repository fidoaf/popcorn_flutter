import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/media_share.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Material share button that opens the share sheet for [item].
class MaterialShareButton extends StatelessWidget {
  const MaterialShareButton({super.key, required this.item, required this.type, this.iconSize = 24});

  final MediaItem item;
  final MediaType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      iconSize: iconSize,
      tooltip: DetailsTranslations.share.trOf(context),
      onPressed: () => shareMedia(context, item, type),
    );
  }
}
