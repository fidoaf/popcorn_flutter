extension StringExtension on String {
  bool get isInt {
    return int.tryParse(this) != null;
  }
}
