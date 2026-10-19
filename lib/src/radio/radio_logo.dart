import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:popcorn_flutter/src/radio/radio_station.dart';

class RadioLogo extends StatelessWidget {
  const RadioLogo({super.key, required this.station});

  final RadioStation station;
  static const _placeholder = Center(child: Icon(Icons.radio, color: Color(0xFF9BA9B4), size: 40));

  @override
  Widget build(BuildContext context) {
    final url = station.logoUrl;
    if (url == null) return _placeholder;
    if (url.path.toLowerCase().endsWith('.svg')) {
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
