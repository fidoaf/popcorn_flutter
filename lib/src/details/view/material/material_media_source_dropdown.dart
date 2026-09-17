import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/player/domain/media_source_provider.dart';
import 'package:popcorn_flutter/src/player/infrastructure/media_source/configurable_media_source_provider.dart';

/// Dropdown that selects the active streaming backend on [provider], letting
/// the viewer switch the media source used by the details play button.
///
/// Hidden when there is nothing to choose from (fewer than two providers).
class MaterialMediaSourceDropdown extends StatefulWidget {
  const MaterialMediaSourceDropdown({super.key, required this.provider});

  final ConfigurableMediaSourceProvider provider;

  @override
  State<MaterialMediaSourceDropdown> createState() => _MaterialMediaSourceDropdownState();
}

class _MaterialMediaSourceDropdownState extends State<MaterialMediaSourceDropdown> {
  @override
  Widget build(BuildContext context) {
    final providers = widget.provider.providers.toList(growable: false);
    if (providers.length < 2) return const SizedBox.shrink();

    return DropdownButtonHideUnderline(
      child: DropdownButton<MediaSourceProvider>(
        value: widget.provider.delegate,
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.arrow_drop_down),
        hint: Text(DetailsTranslations.provider.trOf(context)),
        items: [
          for (final source in providers) DropdownMenuItem(value: source, child: Text(source.name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (source) {
          if (source == null) return;
          setState(() => widget.provider.delegate = source);
        },
      ),
    );
  }
}
