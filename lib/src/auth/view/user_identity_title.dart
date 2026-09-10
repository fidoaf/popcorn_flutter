import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/profile/view/profile_avatar.dart';
import 'package:popcorn_flutter/src/profile/view/profile_controller.dart';
import 'package:popcorn_flutter/src/profile/view/profile_sheet.dart';

/// App-bar/toolbar title that greets the user with the active profile's avatar
/// and name, falling back to the auth identity and then [fallbackTitle].
///
/// When a [profileController] is supplied, tapping the title opens the profile
/// switcher (pick, add, edit, sign out). Debug guest sessions show a localized
/// "Guest" placeholder.
class UserIdentityTitle extends StatelessWidget {
  const UserIdentityTitle({super.key, required this.controller, required this.fallbackTitle, this.profileController, this.avatarSize = 30});

  final AuthController controller;
  final ProfileController? profileController;
  final Widget fallbackTitle;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, profileController]),
      builder: (context, _) {
        final profile = profileController?.activeProfile;
        final name = profile?.displayName ?? controller.firstName ?? (controller.isGuest ? AuthTranslations.guestName.trOf(context) : null);
        if (name == null) return fallbackTitle;

        final avatarUrl = _resolveAvatarUrl(profile?.avatarUrl, controller.avatarUrl);
        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(url: avatarUrl, initial: name.substring(0, 1).toUpperCase(), size: avatarSize),
            const SizedBox(width: 10),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          ],
        );

        final switcher = profileController;
        if (switcher == null) return content;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showProfileSheet(context, profileController: switcher, authController: controller),
          child: MouseRegion(cursor: SystemMouseCursors.click, child: content),
        );
      },
    );
  }
}

String? _nonEmpty(String? value) => (value == null || value.trim().isEmpty) ? null : value;

// Google avatar URLs carry a rotating token that expires, so a snapshot stored
// on the profile goes stale. Prefer the live session avatar over a stored
// googleusercontent URL; a custom (uploaded) avatar still wins.
String? _resolveAvatarUrl(String? profileUrl, String? liveUrl) {
  final profileAvatar = _nonEmpty(profileUrl);
  final liveAvatar = _nonEmpty(liveUrl);
  if (profileAvatar != null && profileAvatar.contains('googleusercontent.com') && liveAvatar != null) {
    return liveAvatar;
  }
  return profileAvatar ?? liveAvatar;
}
