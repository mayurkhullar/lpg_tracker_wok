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


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final entries = entriesAsync.value ?? [];
    final isLoading = entriesAsync.isLoading;
    final today = normalizeDate(DateTime.now());

    final todayMatches = entries.where((e) => normalizeDate(e.date) == today).toList();
    final todayEntry = todayMatches.isEmpty ? null : todayMatches.first;

    final monthEntries = entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .toList();

    final monthlyTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);
    final todayGasCost = todayEntry?.gasCost;
    final todayUsage = (todayEntry != null && isValidUsageEntry(entries, todayEntry))
        ? todayEntry.usage
        : null;
    final todayEfficiency = gasPer1000Sales(
      gasUsed: todayUsage,
      sales: todayEntry?.sales,
    );

    final monthCostEntries = monthEntries.where((entry) => entry.gasCost != null).toList();
    final monthlyGasCost = monthCostEntries.fold<double>(0, (sum, entry) => sum + entry.gasCost!);

    final monthAverage = monthEntries.isEmpty ? null : monthlyTotal / monthEntries.length;
    final todayUsageColor = _getUsageColor(
      context: context,
      usage: todayUsage,
      average: monthAverage,
    );

    final highUsageInsight = buildHighUsageInsight(entries, today: today);
    final weeklySummary = buildLast7DaysSummary(entries, today: today);

    final weeklyCostEntries = weeklySummary.validEntries.where((entry) => entry.gasCost != null).toList();
    final weeklyGasCost = weeklyCostEntries.fold<double>(0, (sum, entry) => sum + entry.gasCost!);

    InsightBanner? insightBanner;
    if (todayEntry?.isAnomaly ?? false) {
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
                title: 'Gas Used Today',
                value: _usageDisplay(entries, todayEntry),
                isPrimary: true,
                color: todayUsageColor,
              ),
              const SizedBox(height: 12),
              ResponsiveGrid(
                children: [
                  StatCard(
                    title: 'Gas Remaining',
                    value: todayEntry == null ? '—' : '${todayEntry.gasRemaining.toStringAsFixed(2)} kg',
                  ),
                  StatCard(
                    title: 'Gas Cost Today',
                    value: _currencyDisplay(todayGasCost),
                  ),
                  StatCard(
                    title: 'Sales Today',
                    value: todayEntry == null ? '—' : '₹${todayEntry.sales.toStringAsFixed(2)}',
                  ),
                  StatCard(
                    title: 'Gas per ₹1000 Sales',
                    value: _gasPerThousandDisplay(todayEfficiency),
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
                  message: '⚠ Higher than usual usage today '
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
