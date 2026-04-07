import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import '../widgets/entry_summary_card.dart';
import '../utils/insight_calculations.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/metric_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _usageDisplay(List<DailyEntry> entries, DailyEntry? entry) {
    if (entry == null || !isValidUsageEntry(entries, entry)) return '—';
    return '${entry.usage.toStringAsFixed(2)} kg';
  }

  String _currencyDisplay(double? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  String _usageOnlyDisplay(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)} kg';
  }

  String _gasPerThousandDisplay(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)} kg / ₹1000 sales';
  }

  String _usageDayDisplay(DailyEntry? entry) {
    if (entry == null) return '—';
    return '${DateFormat.MMMd().format(entry.date)} • ${entry.usage.toStringAsFixed(2)} kg';
  }

  Color _getUsageColor({
    required BuildContext context,
    required double? usage,
    required double? average,
  }) {
    if (usage == null || average == null || average <= 0) {
      return Theme.of(context).colorScheme.onSurface;
    }
    if (usage > average * 1.3) return Colors.orange.shade700;
    if (usage < average * 0.7) return Colors.green.shade700;
    return Theme.of(context).colorScheme.onSurface;
  }

  bool _isYesterday(DateTime date, DateTime today) {
    final normalizedToday = normalizeDate(today);
    final normalizedDate = normalizeDate(date);
    return normalizedDate == normalizedToday.subtract(const Duration(days: 1));
  }

  String _labelPrefix(DailyEntry? latestEntry, DateTime today) {
    if (latestEntry == null) return 'Latest';
    return _isYesterday(latestEntry.date, today) ? "Yesterday's" : 'Latest';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final entries = entriesAsync.value ?? [];
    final isLoading = entriesAsync.isLoading;
    final today = normalizeDate(DateTime.now());
    final latestEntry = entries.isEmpty ? null : entries.first;
    final labelPrefix = _labelPrefix(latestEntry, today);
    final latestDateText = latestEntry == null ? '' : DateFormat.yMMMd().format(latestEntry.date);

    final monthEntries = entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .toList();

    final monthlyTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);
    final latestGasCost = latestEntry?.gasCost;
    final latestUsage = (latestEntry != null && isValidUsageEntry(entries, latestEntry))
        ? latestEntry.usage
        : null;
    final latestEfficiency = gasPer1000Sales(
      gasUsed: latestUsage,
      sales: latestEntry?.sales,
    );

    final monthCostEntries = monthEntries.where((entry) => entry.gasCost != null).toList();
    final monthlyGasCost = monthCostEntries.fold<double>(0, (sum, entry) => sum + entry.gasCost!);

    final monthAverage = monthEntries.isEmpty ? null : monthlyTotal / monthEntries.length;
    final latestUsageColor = _getUsageColor(
      context: context,
      usage: latestUsage,
      average: monthAverage,
    );

    final insightReferenceDay = latestEntry?.date ?? today;
    final highUsageInsight = buildHighUsageInsight(entries, today: insightReferenceDay);
    final weeklySummary = buildLast7DaysSummary(entries, today: today);

    final weeklyCostEntries = weeklySummary.validEntries.where((entry) => entry.gasCost != null).toList();
    final weeklyGasCost = weeklyCostEntries.fold<double>(0, (sum, entry) => sum + entry.gasCost!);

    InsightBanner? insightBanner;
    if (latestEntry?.isAnomaly ?? false) {
      insightBanner = InsightBanner(
        message: 'Anomaly detected in usage trend. Please verify readings.',
        icon: Icons.warning_amber_rounded,
        textColor: Colors.orange.shade900,
        backgroundColor: Colors.orange.withValues(alpha: 0.15),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyEntriesProvider);
          await ref.read(dailyEntriesProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              StatCard(
                title: '$labelPrefix Gas Used${latestDateText.isEmpty ? '' : ' ($latestDateText)'}',
                value: _usageDisplay(entries, latestEntry),
                isPrimary: true,
                color: latestUsageColor,
              ),
              const SizedBox(height: 12),
              ResponsiveGrid(
                children: [
                  StatCard(
                    title: '$labelPrefix Gas Remaining',
                    value: latestEntry == null ? '—' : '${latestEntry.gasRemaining.toStringAsFixed(2)} kg',
                  ),
                  StatCard(
                    title: '$labelPrefix Gas Cost',
                    value: _currencyDisplay(latestGasCost),
                  ),
                  StatCard(
                    title: '$labelPrefix Sales',
                    value: latestEntry == null ? '—' : '₹${latestEntry.sales.toStringAsFixed(2)}',
                  ),
                  StatCard(
                    title: 'Gas per ₹1000 Sales',
                    value: _gasPerThousandDisplay(latestEfficiency),
                    valueMaxLines: 3,
                  ),
                  StatCard(
                    title: 'Monthly Total',
                    value: '${monthlyTotal.toStringAsFixed(2)} kg',
                  ),
                  StatCard(
                    title: 'Monthly Gas Cost',
                    value: _currencyDisplay(monthCostEntries.isEmpty ? null : monthlyGasCost),
                  ),
                ],
              ),
              if (highUsageInsight.isHighUsage) ...[
                const SizedBox(height: 12),
                InsightBanner(
                  message: '⚠ Higher than usual usage in latest entry '
                      '(+${highUsageInsight.percentAboveAverage!.toStringAsFixed(0)}%)',
                  icon: Icons.warning_amber_rounded,
                  textColor: Colors.orange.shade900,
                  backgroundColor: Colors.orange.withValues(alpha: 0.10),
                ),
              ],
              if (insightBanner != null) ...[
                const SizedBox(height: 12),
                insightBanner,
              ],
              const SizedBox(height: kSectionSpacing),
              const SectionHeader('Last 7 Days Summary'),
              const SizedBox(height: 12),
              ResponsiveGrid(
                childAspectRatio: 1.35,
                children: [
                  StatCard(
                    title: 'Total Gas Used (7 days)',
                    value: _usageOnlyDisplay(weeklySummary.totalGasUsed),
                  ),
                  StatCard(
                    title: 'Average Daily Usage',
                    value: _usageOnlyDisplay(weeklySummary.averageDailyUsage),
                  ),
                  StatCard(
                    title: 'Highest Usage Day',
                    value: _usageDayDisplay(weeklySummary.highestUsageEntry),
                    valueMaxLines: 3,
                  ),
                  StatCard(
                    title: 'Total Gas Cost (7 days)',
                    value: _currencyDisplay(weeklyCostEntries.isEmpty ? null : weeklyGasCost),
                  ),
                  StatCard(
                    title: 'Total Sales (7 days)',
                    value: _currencyDisplay(weeklySummary.totalSales),
                  ),
                ],
              ),
              const SizedBox(height: kSectionSpacing),
              const SectionHeader('Recent Entries'),
              const SizedBox(height: 12),
              ...entries.take(3).map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EntrySummaryCard(
                    date: entry.date,
                    gasUsedText: _usageDisplay(entries, entry),
                    gasCostText: _currencyDisplay(entry.gasCost),
                    salesText: '₹${entry.sales.toStringAsFixed(2)}',
                    gasUsedColor: _getUsageColor(
                      context: context,
                      usage: entry.usage,
                      average: monthAverage,
                    ),
                    trailing: Icon(
                      entry.isAnomaly ? Icons.warning_amber_rounded : Icons.check_circle,
                      color: entry.isAnomaly ? Colors.orange : Colors.blue,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
