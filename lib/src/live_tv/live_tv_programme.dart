final class LiveTvProgramme {
  const LiveTvProgramme({required this.title, required this.description, required this.start, required this.end});

  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  factory LiveTvProgramme.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final start = json['start'] is String ? DateTime.tryParse(json['start'] as String) : null;
    final end = json['end'] is String ? DateTime.tryParse(json['end'] as String) : null;
    if (title is! String || title.isEmpty || start == null || end == null || !end.isAfter(start)) {
      throw const FormatException('Invalid live TV programme');
    }
    return LiveTvProgramme(
      title: title,
      description: json['description'] is String ? json['description'] as String : '',
      start: start,
      end: end,
    );
  }
}
