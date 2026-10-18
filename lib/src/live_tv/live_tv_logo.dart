import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:popcorn_flutter/src/live_tv/live_tv_channel.dart';

class LiveTvLogo extends StatelessWidget {
  const LiveTvLogo({super.key, required this.channel});

  final LiveTvChannel channel;

  static const _placeholder = Center(child: Icon(Icons.live_tv, color: Color(0xFF9BA9B4), size: 36));

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    if (url == null) return _placeholder;
    if (channel.hasSvgLogo) {
      return SvgPicture.network(
        url.toString(),
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _placeholder,
        errorBuilder: (context, error, stack) => _placeholder,
      );
    }
    return Image.network(url.toString(), fit: BoxFit.contain, errorBuilder: (context, error, stack) => _placeholder);
  }
}
