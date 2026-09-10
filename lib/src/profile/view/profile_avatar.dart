import 'package:flutter/widgets.dart';

/// A circular avatar showing a network [url] when available, or a colored
/// circle with the name's [initial] as a fallback/placeholder.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, required this.initial, this.size = 30});

  final String? url;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = _initialAvatar();
    final source = url;
    if (source == null || source.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('$error');
          return placeholder;
        },
        loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
      ),
    );
  }

  Widget _initialAvatar() => Container(
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
