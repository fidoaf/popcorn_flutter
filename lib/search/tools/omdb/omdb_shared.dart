const _unkown = 'N/A';
void purgeData(Map<String, dynamic> data) {
  for (final entry in data.entries) {
    if (entry.value == _unkown) {
      data[entry.key] = null;
    }
  }
}