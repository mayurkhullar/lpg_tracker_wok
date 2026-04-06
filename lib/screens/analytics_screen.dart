import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/purchase_repository.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/metric_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  String _currencyDisplay(double? value) {
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = (ref.watch(dailyEntriesProvider).value ?? []).reversed.toList();
    final purchases = ref.watch(purchasesProvider).value ?? [];
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);

    if (entries.isEmpty) {
      return const Center(child: Text('No analytics yet. Add entries first.'));
    }

    final month = DateTime.now();
    final monthEntries = entries
        .where((e) => e.date.month == month.month && e.date.year == month.year)
        .toList();

    final total = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);
    final avg = monthEntries.isEmpty ? 0.0 : total / monthEntries.length;
    final highest = monthEntries.isEmpty
        ? 0.0
        : monthEntries.map((e) => e.usage).reduce((a, b) => a > b ? a : b);
    final salesTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.sales);
    final salesPerKgDisplay = total > 0 ? '₹${(salesTotal / total).toStringAsFixed(2)} / kg' : '—';
    var daysWithCost = 0;
    final monthlyGasCost = monthEntries.fold<double>(0, (sum, entry) {
      final costPerCylinder = purchaseRepository.resolveCostPerCylinderForDate(entry.date, purchases);
      if (costPerCylinder == null) return sum;
      daysWithCost += 1;
      final costPerKg = costPerCylinder / gasPerCylinder;
      return sum + (entry.usage * costPerKg);
    });
    final averageCostPerDay = daysWithCost == 0 ? null : monthlyGasCost / daysWithCost;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Daily Usage'),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 240,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: BarChart(
                    BarChartData(
                      barGroups: [
                        for (int i = 0; i < entries.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: entries[i].usage,
                                width: 12,
                                color: entries[i].isAnomaly ? Colors.orange : Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Summary'),
            const SizedBox(height: 16),
            ResponsiveMetricGrid(
              children: [
                MetricCard(
                  title: 'Monthly Total',
                  value: '${total.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                MetricCard(
                  title: 'Monthly Avg',
                  value: '${avg.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                MetricCard(
                  title: 'Highest Day',
                  value: '${highest.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                MetricCard(
                  title: 'Sales per kg',
                  value: salesPerKgDisplay,
                  fitValue: true,
                ),
                MetricCard(
                  title: 'Monthly Gas Cost',
                  value: _currencyDisplay(daysWithCost == 0 ? null : monthlyGasCost),
                  fitValue: true,
                ),
                MetricCard(
                  title: 'Avg Cost / Day',
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
