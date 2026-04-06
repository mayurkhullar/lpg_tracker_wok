import '../models/daily_entry.dart';
import 'date_utils.dart';

class HighUsageInsight {
  const HighUsageInsight({
    required this.isHighUsage,
    required this.todayUsage,
    required this.recentAverage,
    required this.validUsageCount,
  });

  final bool isHighUsage;
  final double? todayUsage;
  final double? recentAverage;
  final int validUsageCount;

  double? get percentAboveAverage {
    if (!isHighUsage || todayUsage == null || recentAverage == null || recentAverage! <= 0) {
      return null;
    }
    return ((todayUsage! - recentAverage!) / recentAverage!) * 100;
  }
}

class WeeklySummary {
  const WeeklySummary({
    required this.validEntries,
    required this.totalGasUsed,
    required this.averageDailyUsage,
    required this.highestUsageEntry,
    required this.totalSales,
  });

  final List<DailyEntry> validEntries;
  final double? totalGasUsed;
  final double? averageDailyUsage;
  final DailyEntry? highestUsageEntry;
  final double? totalSales;
}

bool hasPreviousEntry(List<DailyEntry> entries, DateTime date) {
  final target = normalizeDate(date);
  return entries.any((entry) => normalizeDate(entry.date).isBefore(target));
}

bool isValidUsageEntry(List<DailyEntry> entries, DailyEntry entry) {
  return hasPreviousEntry(entries, entry.date) && entry.usage.isFinite && entry.usage >= 0;
}

List<DailyEntry> validUsageEntriesInRange(
  List<DailyEntry> entries, {
  required DateTime start,
  required DateTime end,
}) {
  final startDay = normalizeDate(start);
  final endDay = normalizeDate(end);
  return entries.where((entry) {
    final date = normalizeDate(entry.date);
    if (date.isBefore(startDay) || date.isAfter(endDay)) return false;
    return isValidUsageEntry(entries, entry);
  }).toList();
}

HighUsageInsight buildHighUsageInsight(
  List<DailyEntry> entries, {
  required DateTime today,
}) {
  final todayDay = normalizeDate(today);
  final todayEntry = entries.where((entry) => normalizeDate(entry.date) == todayDay).fold<DailyEntry?>(
        null,
        (latest, entry) {
          if (latest == null) return entry;
          return entry.date.isAfter(latest.date) ? entry : latest;
        },
      );

  final previousValidEntries = entries
      .where((entry) => normalizeDate(entry.date).isBefore(todayDay))
      .where((entry) => isValidUsageEntry(entries, entry))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final recentValidEntries = previousValidEntries.take(7).toList();
  final validUsageCount = recentValidEntries.length;
  final recentAverage = validUsageCount == 0
      ? null
      : recentValidEntries.fold<double>(0, (sum, entry) => sum + entry.usage) / validUsageCount;

  final todayUsage = (todayEntry != null && isValidUsageEntry(entries, todayEntry))
      ? todayEntry.usage
      : null;

  final isHighUsage = todayUsage != null &&
      recentAverage != null &&
      validUsageCount >= 3 &&
      todayUsage > recentAverage * 1.2;

  return HighUsageInsight(
    isHighUsage: isHighUsage,
    todayUsage: todayUsage,
    recentAverage: recentAverage,
    validUsageCount: validUsageCount,
  );
}

double? gasPer1000Sales({
  required double? gasUsed,
  required double? sales,
}) {
  if (gasUsed == null || sales == null || sales <= 0) return null;
  return (gasUsed / sales) * 1000;
}

WeeklySummary buildLast7DaysSummary(List<DailyEntry> entries, {required DateTime today}) {
  final end = normalizeDate(today);
  final start = normalizeDate(end.subtract(const Duration(days: 6)));
  final validEntries = validUsageEntriesInRange(entries, start: start, end: end)
    ..sort((a, b) => a.date.compareTo(b.date));

  if (validEntries.isEmpty) {
    return const WeeklySummary(
      validEntries: [],
      totalGasUsed: null,
      averageDailyUsage: null,
      highestUsageEntry: null,
      totalSales: null,
    );
  }

  final totalGasUsed = validEntries.fold<double>(0, (sum, entry) => sum + entry.usage);
  final totalSales = validEntries.fold<double>(0, (sum, entry) => sum + entry.sales);
  final highestUsageEntry = validEntries.reduce(
    (current, next) => next.usage > current.usage ? next : current,
  );

  return WeeklySummary(
    validEntries: validEntries,
    totalGasUsed: totalGasUsed,
    averageDailyUsage: totalGasUsed / validEntries.length,
    highestUsageEntry: highestUsageEntry,
    totalSales: totalSales,
  );
}
