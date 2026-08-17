import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/media_share.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// macOS share button that opens the share sheet for [item].
class MacosShareButton extends StatelessWidget {
  const MacosShareButton({super.key, required this.item, required this.type, this.iconSize = 20});

  final MediaItem item;
  final MediaType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return MacosTooltip(
      message: DetailsTranslations.share.trOf(context),
      child: MacosIconButton(
        icon: MacosIcon(CupertinoIcons.share, size: iconSize),
        onPressed: () => shareMedia(context, item, type),
      ),
    );
  }
}
