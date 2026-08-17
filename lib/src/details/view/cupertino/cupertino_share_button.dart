import 'package:flutter/cupertino.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/media_share.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Cupertino share button that opens the share sheet for [item].
class CupertinoShareButton extends StatelessWidget {
  const CupertinoShareButton({super.key, required this.item, required this.type, this.iconSize = 24});

  final MediaItem item;
  final MediaType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => shareMedia(context, item, type),
      child: Semantics(
        label: DetailsTranslations.share.trOf(context),
        child: Icon(CupertinoIcons.share, size: iconSize),
      ),
    );
  }
}
