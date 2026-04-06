DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

String dayId(DateTime date) {
  final d = normalizeDate(date);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
