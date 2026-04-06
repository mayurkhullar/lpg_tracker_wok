import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
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
    final recentEntries = sortedEntries.length <= 7
        ? sortedEntries
        : sortedEntries.sublist(sortedEntries.length - 7);

    final month = DateTime.now();
    final monthEntries = allEntries
        .where((e) => e.date.month == month.month && e.date.year == month.year)
        .toList();

    final total = monthEntries.fold<double>(0, (sum, e) => sum + e.usage);
    final avg = monthEntries.isEmpty ? 0.0 : total / monthEntries.length;
    final highest = monthEntries.isEmpty
        ? 0.0
        : monthEntries.map((e) => e.usage).reduce((a, b) => a > b ? a : b);
    final salesTotal = monthEntries.fold<double>(0, (sum, e) => sum + e.sales);
    final salesPerKgDisplay =
        total > 0 ? '₹${(salesTotal / total).toStringAsFixed(2)} / kg' : '—';
    return SafeArea(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Last 7 Days Usage'),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: AspectRatio(
                    aspectRatio: 1.8,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, _, rod, __) {
                              final entry = recentEntries[group.x.toInt()];
                              return BarTooltipItem(
                                '${DateFormat.Md().format(entry.date)}\n${rod.toY.toStringAsFixed(2)} kg',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        barGroups: [
                          for (int i = 0; i < recentEntries.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: recentEntries[i].usage,
                                  width: 16,
                                  color: recentEntries[i].isAnomaly
                                      ? Colors.orange
                                      : Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                        ],
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            axisNameWidget: const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Date'),
                            ),
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= recentEntries.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    DateFormat.Md().format(recentEntries[index].date),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            axisNameWidget: const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text('kg'),
                            ),
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: kSectionSpacing),
            const SectionHeader('Summary'),
            const SizedBox(height: 12),
            ResponsiveGrid(
              children: [
                StatCard(
                  title: 'Monthly Total',
                  value: '${total.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                StatCard(
                  title: 'Monthly Avg',
                  value: '${avg.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                StatCard(
                  title: 'Highest Day',
                  value: '${highest.toStringAsFixed(2)} kg',
                  fitValue: true,
                ),
                StatCard(
                  title: 'Sales per kg',
                  value: salesPerKgDisplay,
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
