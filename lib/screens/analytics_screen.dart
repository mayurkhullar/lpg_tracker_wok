import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/purchase_repository.dart';
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
    final ratio = total == 0 ? 0 : salesTotal / total;
    var daysWithCost = 0;
    final monthlyGasCost = monthEntries.fold<double>(0, (sum, entry) {
      final costPerCylinder = purchaseRepository.resolveCostPerCylinderForDate(entry.date, purchases);
      if (costPerCylinder == null) return sum;
      daysWithCost += 1;
      final costPerKg = costPerCylinder / gasPerCylinder;
      return sum + (entry.usage * costPerKg);
    });
    final averageCostPerDay = daysWithCost == 0 ? null : monthlyGasCost / daysWithCost;
    final costToSalesRatio = salesTotal == 0 ? null : monthlyGasCost / salesTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Daily Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            MetricCard(title: 'Monthly Total', value: '${total.toStringAsFixed(2)} kg'),
            MetricCard(title: 'Monthly Avg', value: '${avg.toStringAsFixed(2)} kg'),
            MetricCard(title: 'Highest Day', value: '${highest.toStringAsFixed(2)} kg'),
            MetricCard(title: 'Sales/Usage', value: '₹ ${ratio.toStringAsFixed(2)} /kg'),
            MetricCard(
              title: 'Monthly Gas Cost',
              value: _currencyDisplay(daysWithCost == 0 ? null : monthlyGasCost),
            ),
            MetricCard(
              title: 'Avg Cost / Day',
              value: _currencyDisplay(averageCostPerDay),
            ),
            MetricCard(
              title: 'Cost/Sales Ratio',
              value: costToSalesRatio == null ? '—' : costToSalesRatio.toStringAsFixed(2),
            ),
          ],
        ),
      ],
    );
  }
}
