import 'package:fluent_ui/fluent_ui.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/details/view/media_share.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';

/// Fluent share button that opens the share sheet for [item].
class FluentShareButton extends StatelessWidget {
  const FluentShareButton({super.key, required this.item, required this.type, this.iconSize});

  final MediaItem item;
  final MediaType type;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: DetailsTranslations.share.trOf(context),
      child: IconButton(
        icon: Icon(FluentIcons.share, size: iconSize),
        onPressed: () => shareMedia(context, item, type),
      ),
    );
  }
}
