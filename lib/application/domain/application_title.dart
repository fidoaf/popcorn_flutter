import 'package:popcorn_flutter/common/domain/text.dart';

class ApplicationTitle {
  final Text text;
  ApplicationTitle._({required this.text});

  factory ApplicationTitle.create({required String text}) {
    return ApplicationTitle._(text: Text.create(text: text));
  }

  @override
  String toString() {
    return text.value;
  }
}
