import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:popcorn_flutter/src/auth/view/auth_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';

/// App-bar/toolbar title that greets the signed-in user with their avatar and
/// first name, falling back to [fallbackTitle] when no profile is available.
/// Debug guest sessions show a localized "Guest" placeholder instead.
class UserIdentityTitle extends StatelessWidget {
  const UserIdentityTitle({super.key, required this.controller, required this.fallbackTitle, this.avatarSize = 30});

  final AuthController controller;
  final Widget fallbackTitle;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final name = controller.firstName ?? (controller.isGuest ? AuthTranslations.guestName.trOf(context) : null);
        if (name == null) return fallbackTitle;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(url: controller.avatarUrl, initial: name.substring(0, 1).toUpperCase(), size: avatarSize),
            const SizedBox(width: 10),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.initial, required this.size});

  final String? url;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = _initialAvatar();
    if (url == null) return placeholder;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
      ),
    );
  }

  Widget _initialAvatar() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFF7E57C2), shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: size * 0.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
