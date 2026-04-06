import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import '../widgets/metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dailyEntriesProvider).value ?? [];
    final today = normalizeDate(DateTime.now());

    final todayMatches = entries.where((e) => normalizeDate(e.date) == today).toList();
    final yesterdayMatches = entries
        .where((e) => normalizeDate(e.date) == today.subtract(const Duration(days: 1)))
        .toList();
    final todayEntry = todayMatches.isEmpty ? null : todayMatches.first;
    final yesterdayEntry = yesterdayMatches.isEmpty ? null : yesterdayMatches.first;

    final monthEntries = entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .toList();

    final monthlyTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if ((todayEntry?.isAnomaly ?? false) || (entries.isNotEmpty && entries.first.isAnomaly))
          Card(
            color: Colors.orange.withValues(alpha: 0.2),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Anomaly detected in usage trend. Please verify readings.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            MetricCard(
              title: 'Today Usage',
              value: todayEntry == null ? 'No entry yet' : '${todayEntry.usage.toStringAsFixed(2)} kg',
            ),
            MetricCard(
              title: 'Sales Today',
              value: todayEntry == null ? '₹ 0' : '₹ ${todayEntry.sales.toStringAsFixed(2)}',
            ),
            MetricCard(
              title: 'Yesterday Usage',
              value: yesterdayEntry == null ? '--' : '${yesterdayEntry.usage.toStringAsFixed(2)} kg',
            ),
            MetricCard(
              title: 'Monthly Total',
              value: '${monthlyTotal.toStringAsFixed(2)} kg',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Recent Entries', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...entries.take(3).map((entry) => Card(
              child: ListTile(
                title: Text(DateFormat.yMMMd().format(entry.date)),
                subtitle: Text('Usage: ${entry.usage.toStringAsFixed(2)} kg • Sales: ₹ ${entry.sales.toStringAsFixed(2)}'),
                trailing: entry.isAnomaly
                    ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                    : const Icon(Icons.check_circle, color: Colors.blue),
              ),
            )),
      ],
    );
  }
}
