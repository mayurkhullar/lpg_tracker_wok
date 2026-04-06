import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/metric_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntries = ref.watch(dailyEntriesProvider).value ?? [];
    if (allEntries.isEmpty) {
      return const Center(child: Text('No analytics yet. Add entries first.'));
    }

    final sortedEntries = [...allEntries]..sort((a, b) => a.date.compareTo(b.date));
    final lastDate = normalizeDate(sortedEntries.last.date);
    final windowStart = lastDate.subtract(const Duration(days: 6));
    final usageByDate = <DateTime, DailyEntry>{};
    for (final entry in sortedEntries) {
      usageByDate[normalizeDate(entry.date)] = entry;
    }

    final recentDates = List.generate(
      7,
      (index) => normalizeDate(windowStart.add(Duration(days: index))),
    );
    final recentEntries = recentDates.map((date) => usageByDate[date]).toList();

    final validUsageEntries = recentEntries
        .whereType<DailyEntry>()
        .where((entry) => entry.usage.isFinite && entry.usage >= 0)
        .toList();
    final usageValues = validUsageEntries.map((entry) => entry.usage).toList();

    final totalUsage = usageValues.fold<double>(0, (sum, usage) => sum + usage);
    final averageUsage = usageValues.isEmpty ? 0.0 : totalUsage / usageValues.length;

    DailyEntry? highestUsageEntry;
    DailyEntry? lowestUsageEntry;

    if (validUsageEntries.isNotEmpty) {
      highestUsageEntry = validUsageEntries.reduce(
        (current, next) => next.usage > current.usage ? next : current,
      );
      lowestUsageEntry = validUsageEntries.reduce(
        (current, next) => next.usage < current.usage ? next : current,
      );
    }

    String formatDayUsage(DailyEntry? entry) {
      if (entry == null) return '—';
      return '${entry.usage.toStringAsFixed(2)} kg\n${DateFormat.MMMd().format(entry.date)}';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Last 7 Days Summary'),
            const SizedBox(height: 12),
            ResponsiveGrid(
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: 'Total Usage',
                  value: '${totalUsage.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                StatCard(
                  title: 'Average Daily Usage',
                  value: '${averageUsage.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                StatCard(
                  title: 'Highest Usage Day',
                  value: formatDayUsage(highestUsageEntry),
                  valueMaxLines: 3,
                ),
                StatCard(
                  title: 'Lowest Usage Day',
                  value: formatDayUsage(lowestUsageEntry),
                  valueMaxLines: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
