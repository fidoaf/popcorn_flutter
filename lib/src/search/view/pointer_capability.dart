import 'package:flutter/foundation.dart';

/// Whether the current platform is primarily operated by touch.
///
/// Touch platforms (phones/tablets) should surface per-item actions like the
/// play button permanently, while desktop platforms (with a pointer) reveal
/// them on hover. On the web this reflects the underlying operating system, so
/// a desktop browser is treated as a pointer device and a mobile browser as
/// touch.
bool get isTouchPrimaryPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return false;
  }
}
