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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  bool _hasPreviousEntry(List<DailyEntry> entries, DateTime date) {
    final target = normalizeDate(date);
    return entries.any((entry) => normalizeDate(entry.date).isBefore(target));
  }

  String _usageDisplay(List<DailyEntry> entries, DailyEntry? entry) {
    if (entry == null) return '—';
    if (!_hasPreviousEntry(entries, entry.date)) return '—';
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

  double? _dailyGasCost({
    required DailyEntry? entry,
    required List<Purchase> purchases,
    required PurchaseRepository purchaseRepository,
  }) {
    if (entry == null) return null;
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
    final entries = ref.watch(dailyEntriesProvider).value ?? [];
    final purchases = ref.watch(purchasesProvider).value ?? [];
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);
    final today = normalizeDate(DateTime.now());

    final todayMatches = entries.where((e) => normalizeDate(e.date) == today).toList();
    final todayEntry = todayMatches.isEmpty ? null : todayMatches.first;

    final monthEntries = entries
        .where((e) => e.date.year == today.year && e.date.month == today.month)
        .toList();

    final monthlyTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);
    final todayGasCost = _dailyGasCost(
      entry: todayEntry,
      purchases: purchases,
      purchaseRepository: purchaseRepository,
    );

    var monthHasCost = false;
    final monthlyGasCost = monthEntries.fold<double>(0, (sum, entry) {
      final dailyCost = _dailyGasCost(
        entry: entry,
        purchases: purchases,
        purchaseRepository: purchaseRepository,
      );
      if (dailyCost == null) return sum;
      monthHasCost = true;
      return sum + dailyCost;
    });

    final monthAverage = monthEntries.isEmpty ? null : monthlyTotal / monthEntries.length;
    final todayUsage = todayEntry?.usage;

    InsightBanner? insightBanner;
    if ((todayEntry?.isAnomaly ?? false) || (entries.isNotEmpty && entries.first.isAnomaly)) {
      insightBanner = InsightBanner(
        message: 'Anomaly detected in usage trend. Please verify readings.',
        icon: Icons.warning_amber_rounded,
        textColor: Colors.orange.shade900,
        backgroundColor: Colors.orange.withValues(alpha: 0.15),
      );
    } else if (monthAverage != null && todayUsage != null && monthAverage > 0) {
      if (todayUsage > monthAverage) {
        insightBanner = InsightBanner(
          message: 'Higher than usual usage today.',
          icon: Icons.trending_up,
          textColor: Colors.orange.shade900,
          backgroundColor: Colors.orange.withValues(alpha: 0.08),
        );
      } else if (todayUsage < monthAverage) {
        insightBanner = InsightBanner(
          message: 'Lower than average usage today.',
          icon: Icons.trending_down,
          textColor: Colors.green.shade900,
          backgroundColor: Colors.green.withValues(alpha: 0.10),
        );
      } else {
        insightBanner = InsightBanner(
          message:
              'Today usage is in line with monthly average (${_usageOnlyDisplay(monthAverage)}).',
          icon: Icons.analytics_outlined,
          textColor: Colors.blue.shade900,
          backgroundColor: Colors.blue.withValues(alpha: 0.08),
        );
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveGrid(
              children: [
                StatCard(
                  title: 'Gas Used Today',
                  value: _usageDisplay(entries, todayEntry),
                ),
                StatCard(
                  title: 'Gas Remaining Today',
                  value: todayEntry == null
                      ? '—'
                      : '${todayEntry.gasRemaining.toStringAsFixed(2)} kg',
                ),
                StatCard(
                  title: 'Gas Cost Today',
                  value: _currencyDisplay(todayGasCost),
                ),
                StatCard(
                  title: 'Sales Today',
                  value: todayEntry == null
                      ? '—'
                      : '₹${todayEntry.sales.toStringAsFixed(2)}',
                ),
                StatCard(
                  title: 'Monthly Total',
                  value: '${monthlyTotal.toStringAsFixed(2)} kg',
                ),
                StatCard(
                  title: 'Monthly Gas Cost',
                  value: _currencyDisplay(monthHasCost ? monthlyGasCost : null),
                ),
              ],
            ),
            if (insightBanner != null) ...[
              const SizedBox(height: kSectionSpacing),
              insightBanner,
            ],
            const SizedBox(height: kSectionSpacing),
            const SectionHeader('Recent Entries'),
            const SizedBox(height: 12),
            ...entries.take(3).map((entry) {
              final cost = _dailyGasCost(
                entry: entry,
                purchases: purchases,
                purchaseRepository: purchaseRepository,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.yMMMd().format(entry.date),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Gas Used: ${_usageDisplay(entries, entry)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cost: ${_currencyDisplay(cost)} • Sales: ₹${entry.sales.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          entry.isAnomaly
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          color: entry.isAnomaly ? Colors.orange : Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
