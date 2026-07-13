class MediaYear {
  final int year;
  MediaYear._({required this.year});

  factory MediaYear.create({required String text}) {
    if (text.isEmpty) throw ArgumentError.value(text, 'year');
    final numericValue = int.tryParse(text);
    if (numericValue == null) throw ArgumentError('Invalid argument (year): must be numeric');
    if (numericValue.isNegative) throw ArgumentError('Invalid argument (year): must be positive');
    return MediaYear._(year: numericValue);
  }

  @override
  String toString() {
    return '$year';
  }
}
