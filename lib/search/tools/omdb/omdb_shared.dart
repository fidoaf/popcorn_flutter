const _unkown = 'N/A';
void purgeData(Map<String, dynamic> data) {
  for (final entry in data.entries) {
    if (entry.value == _unkown) {
      data[entry.key] = null;
    }
  }
}

List<String> parseList(Map<String, dynamic> data, String key) {
  final rawText = data[key] as String?;
  return rawText?.split(',').map((g) => g.trim()).toList() ?? [];
}
