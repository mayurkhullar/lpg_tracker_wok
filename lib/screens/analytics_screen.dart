import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../models/purchase.dart';
import '../providers/app_providers.dart';
import '../services/purchase_repository.dart';
import '../utils/date_utils.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/metric_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  bool _hasPreviousEntry(List<DailyEntry> entries, DateTime date) {
    final target = normalizeDate(date);
    return entries.any((entry) => normalizeDate(entry.date).isBefore(target));
  }

  bool _isValidUsageEntry(List<DailyEntry> entries, DailyEntry entry) {
    return _hasPreviousEntry(entries, entry.date) && entry.usage.isFinite && entry.usage >= 0;
  }

  String _usageDisplay(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)} kg';
  }

  String _currencyDisplay(double? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  String _usageDayDisplay(DailyEntry? entry) {
    if (entry == null) return '—';
    return '${entry.usage.toStringAsFixed(2)} kg\n${DateFormat.MMMd().format(entry.date)}';
  }

  double? _dailyGasCost({
    required DailyEntry entry,
    required List<Purchase> purchases,
    required PurchaseRepository purchaseRepository,
  }) {
    final costPerCylinder = purchaseRepository.resolveCostPerCylinderForDate(
      entry.date,
      purchases,
    );
    if (costPerCylinder == null) return null;
    final costPerKg = costPerCylinder / gasPerCylinder;
    return entry.usage * costPerKg;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEntries = ref.watch(dailyEntriesProvider).value ?? [];
    if (allEntries.isEmpty) {
      return const Center(child: Text('No analytics yet. Add entries first.'));
    }

    final purchases = ref.watch(purchasesProvider).value ?? [];
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);

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
    final recentEntries = recentDates.map((date) => usageByDate[date]).whereType<DailyEntry>().toList();

    final validRecentEntries = recentEntries
        .where((entry) => _isValidUsageEntry(sortedEntries, entry))
        .toList();

    final totalUsage7Day = validRecentEntries.isEmpty
        ? null
        : validRecentEntries.fold<double>(0, (sum, entry) => sum + entry.usage);
    final averageUsage7Day = validRecentEntries.isEmpty ? null : totalUsage7Day! / validRecentEntries.length;

    final highestUsageEntry7Day = validRecentEntries.isEmpty
        ? null
        : validRecentEntries.reduce(
            (current, next) => next.usage > current.usage ? next : current,
          );
    final lowestUsageEntry7Day = validRecentEntries.isEmpty
        ? null
        : validRecentEntries.reduce(
            (current, next) => next.usage < current.usage ? next : current,
          );

    final monthTargetDate = lastDate;
    final monthEntries = sortedEntries
        .where((entry) =>
            entry.date.year == monthTargetDate.year && entry.date.month == monthTargetDate.month)
        .toList();

    final validMonthEntries = monthEntries
        .where((entry) => _isValidUsageEntry(sortedEntries, entry))
        .toList();

    final monthlyTotal = validMonthEntries.isEmpty
        ? null
        : validMonthEntries.fold<double>(0, (sum, entry) => sum + entry.usage);
    final monthlyAverage =
        validMonthEntries.isEmpty ? null : monthlyTotal! / validMonthEntries.length;

    final highestMonthEntry = validMonthEntries.isEmpty
        ? null
        : validMonthEntries.reduce(
            (current, next) => next.usage > current.usage ? next : current,
          );

    final monthlySales = validMonthEntries.isEmpty
        ? null
        : validMonthEntries.fold<double>(0, (sum, entry) => sum + entry.sales);
    final salesPerKg = (monthlySales == null || monthlyTotal == null || monthlyTotal <= 0)
        ? null
        : monthlySales / monthlyTotal;

    var monthHasCost = false;
    var costDays = 0;
    final monthlyGasCost = validMonthEntries.fold<double>(0, (sum, entry) {
      final dailyCost = _dailyGasCost(
        entry: entry,
        purchases: purchases,
        purchaseRepository: purchaseRepository,
      );
      if (dailyCost == null) return sum;
      monthHasCost = true;
      costDays += 1;
      return sum + dailyCost;
    });

    final monthlyGasCostValue = monthHasCost ? monthlyGasCost : null;
    final averageCostPerDay =
        monthHasCost && costDays > 0 ? monthlyGasCost / costDays : null;

    final insightText = [
      if (averageUsage7Day != null)
        'Average usage this week: ${averageUsage7Day.toStringAsFixed(2)} kg/day',
      if (highestUsageEntry7Day != null)
        'Highest usage was on ${DateFormat.MMMd().format(highestUsageEntry7Day.date)}',
      if (monthlyGasCostValue != null)
        'Gas cost this month is ₹${monthlyGasCostValue.toStringAsFixed(2)}',
    ].join(' • ');

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
                  title: 'Total Gas Used',
                  value: _usageDisplay(totalUsage7Day),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Average Daily Gas Used',
                  value: _usageDisplay(averageUsage7Day),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Highest Usage Day',
                  value: _usageDayDisplay(highestUsageEntry7Day),
                  valueMaxLines: 3,
                ),
                StatCard(
                  title: 'Lowest Usage Day',
                  value: _usageDayDisplay(lowestUsageEntry7Day),
                  valueMaxLines: 3,
                ),
              ],
            ),
            if (insightText.isNotEmpty) ...[
              const SizedBox(height: 12),
              InsightBanner(
                message: insightText,
                icon: Icons.lightbulb_outline,
                textColor: Colors.blue.shade900,
                backgroundColor: Colors.blue.withValues(alpha: 0.08),
              ),
            ],
            const SizedBox(height: kSectionSpacing),
            const SectionHeader('Monthly Summary'),
            const SizedBox(height: 12),
            ResponsiveGrid(
              childAspectRatio: 1.28,
              children: [
                StatCard(
                  title: 'Monthly Total',
                  value: _usageDisplay(monthlyTotal),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Monthly Average',
                  value: _usageDisplay(monthlyAverage),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Highest Day',
                  value: _usageDayDisplay(highestMonthEntry),
                  valueMaxLines: 3,
                ),
                StatCard(
                  title: 'Sales per kg',
                  value: _currencyDisplay(salesPerKg),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Monthly Gas Cost',
                  value: _currencyDisplay(monthlyGasCostValue),
                  fitValue: true,
                ),
                StatCard(
                  title: 'Average Cost per Day',
                  value: _currencyDisplay(averageCostPerDay),
                  fitValue: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
