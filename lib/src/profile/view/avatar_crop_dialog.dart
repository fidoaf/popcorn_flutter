import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/profile/view/profile_translations.dart';

/// Lets the user reposition, center and zoom [image] within a fixed circular
/// frame, returning the cropped PNG bytes, or `null` if cancelled.
Future<Uint8List?> showAvatarCropDialog(BuildContext context, Uint8List image) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AvatarCropDialog(image: image),
  );
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final Uint8List image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final CropController _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(ProfileTranslations.adjustPhoto.trOf(context), style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(ProfileTranslations.adjustPhotoHint.trOf(context), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Crop(
                image: widget.image,
                controller: _controller,
                withCircleUi: true,
                interactive: true,
                fixCropRect: true,
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.6),
                onCropped: _onCropped,
                progressIndicator: const Center(child: CircularProgressIndicator()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _cropping ? null : () => Navigator.of(context).pop(), child: Text(ProfileTranslations.cancel.trOf(context))),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _controller.cropCircle();
                          },
                    child: _cropping
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(ProfileTranslations.save.trOf(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
