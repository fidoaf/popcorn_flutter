class Text {
  final String value;
  Text._(this.value);

  factory Text.create({required String text}) {
    if (text.isEmpty) throw ArgumentError.value(text);
    return Text._(text);
  }
}
