import 'package:popcorn_flutter/common/domain/text.dart';

class MediaTitle {
  final Text text;
  MediaTitle._({required this.text});

  factory MediaTitle.create({required String text}) {
    if (text.isEmpty) throw ArgumentError.value(text);
    return MediaTitle._(text: Text.create(text: text));
  }

  @override
  String toString() {
    return text.value;
  }
}
