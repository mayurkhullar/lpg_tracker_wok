import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../models/purchase.dart';
import '../providers/app_providers.dart';
import '../services/purchase_repository.dart';
import '../utils/date_utils.dart';
import '../utils/insight_calculations.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/metric_card.dart';

enum AnalyticsFilterMode { today, singleDate, dateRange }

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  static const int _maxRangeDays = 180;

  late DateTime _singleDate;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  AnalyticsFilterMode _mode = AnalyticsFilterMode.today;
  String? _rangeError;
  bool _isFiltering = false;

  @override
  void initState() {
    super.initState();
    final today = normalizeDate(DateTime.now());
    _singleDate = today;
    _rangeStart = today;
    _rangeEnd = today;
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

  String _gasPerThousandDisplay(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(2)} kg / ₹1000 sales';
  }

  String _countDisplay(int? value) {
    if (value == null) return '—';
    return value.toString();
  }

  Future<void> _pickSingleDate() async {
    final today = normalizeDate(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _singleDate.isAfter(today) ? today : _singleDate,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (selected == null) return;
    await _runFilterUpdate(() {
      _singleDate = normalizeDate(selected);
      _mode = AnalyticsFilterMode.singleDate;
    });
  }

  Future<void> _pickRangeDate({required bool isStart}) async {
    final today = normalizeDate(DateTime.now());
    final initial = isStart ? _rangeStart : _rangeEnd;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (selected == null) return;
    final normalized = normalizeDate(selected);
    await _runFilterUpdate(() {
      if (isStart) {
        _rangeStart = normalized;
      } else {
        _rangeEnd = normalized;
      }
      _mode = AnalyticsFilterMode.dateRange;
      _rangeError = _validateRange(_rangeStart, _rangeEnd);
    });
  }

  String? _validateRange(DateTime start, DateTime end) {
    final today = normalizeDate(DateTime.now());
    if (end.isBefore(start)) return 'End date must be on or after start date.';
    if (start.isAfter(today) || end.isAfter(today)) return 'Future dates are not allowed.';
    final span = end.difference(start).inDays + 1;
    if (span > _maxRangeDays) return 'Date range cannot exceed $_maxRangeDays days.';
    return null;
  }

  void _setPresetRange(int days) {
    final today = normalizeDate(DateTime.now());
    _runFilterUpdate(() {
      _mode = AnalyticsFilterMode.dateRange;
      _rangeEnd = today;
      _rangeStart = normalizeDate(today.subtract(Duration(days: days - 1)));
      _rangeError = _validateRange(_rangeStart, _rangeEnd);
    });
  }

  Future<void> _runFilterUpdate(VoidCallback update) async {
    setState(() {
      _isFiltering = true;
      update();
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _isFiltering = false);
  }

  Widget _buildDateButton({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text('$label: ${DateFormat.yMMMd().format(value)}'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Filter'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AnalyticsFilterMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: AnalyticsFilterMode.today, label: Text('Today')),
                  ButtonSegment(value: AnalyticsFilterMode.singleDate, label: Text('Single Date')),
                  ButtonSegment(value: AnalyticsFilterMode.dateRange, label: Text('Date Range')),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  _runFilterUpdate(() {
                    _mode = selection.first;
                    if (_mode == AnalyticsFilterMode.today) {
                      final today = normalizeDate(DateTime.now());
                      _singleDate = today;
                      _rangeStart = today;
                      _rangeEnd = today;
                    }
                    _rangeError = _validateRange(_rangeStart, _rangeEnd);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: () => _setPresetRange(7),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Last 7 Days'),
                ),
                FilledButton.tonal(
                  onPressed: () => _setPresetRange(30),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Last 30 Days'),
                ),
              ],
            ),
            if (_mode == AnalyticsFilterMode.singleDate) ...[
              const SizedBox(height: 12),
              _buildDateButton(
                label: 'Date',
                value: _singleDate,
                onTap: _pickSingleDate,
              ),
            ],
            if (_mode == AnalyticsFilterMode.dateRange) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDateButton(
                    label: 'Start',
                    value: _rangeStart,
                    onTap: () => _pickRangeDate(isStart: true),
                  ),
                  _buildDateButton(
                    label: 'End',
                    value: _rangeEnd,
                    onTap: () => _pickRangeDate(isStart: false),
                  ),
                ],
              ),
              if (_rangeError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _rangeError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  double? _dailyGasCost({
    required DailyEntry entry,
    required List<Purchase> purchases,
    required PurchaseRepository purchaseRepository,
  }) {
    if (!entry.usage.isFinite || entry.usage < 0) return null;
    final costPerCylinder = purchaseRepository.resolveCostPerCylinderForDate(
      entry.date,
      purchases,
    );
    if (costPerCylinder == null) return null;
    final costPerKg = costPerCylinder / gasPerCylinder;
    return entry.usage * costPerKg;
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final purchasesAsync = ref.watch(purchasesProvider);
    final allEntries = entriesAsync.value ?? [];
    if (entriesAsync.isLoading && allEntries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (allEntries.isEmpty) {
      return const Center(child: Text('No analytics yet. Add entries first.'));
    }

    final purchases = purchasesAsync.value ?? [];
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);

    final sortedEntries = [...allEntries]..sort((a, b) => a.date.compareTo(b.date));
    final today = normalizeDate(DateTime.now());
    final selectedDay = _mode == AnalyticsFilterMode.today ? today : _singleDate;
    final isRangeMode = _mode == AnalyticsFilterMode.dateRange;
    final hasRangeError = isRangeMode && _rangeError != null;

    final filteredEntries = sortedEntries.where((entry) {
      final date = normalizeDate(entry.date);
      if (!isRangeMode) return date == selectedDay;
      if (hasRangeError) return false;
      return !date.isBefore(_rangeStart) && !date.isAfter(_rangeEnd);
    }).toList();

    final treatAsSingle = !isRangeMode || _rangeStart == _rangeEnd;
    final validFilteredEntries = filteredEntries.where((entry) => isValidUsageEntry(sortedEntries, entry)).toList();

    DailyEntry? singleEntry;
    if (treatAsSingle) {
      singleEntry = filteredEntries.isNotEmpty ? filteredEntries.last : null;
    }

    final singleGasUsed = singleEntry != null && isValidUsageEntry(sortedEntries, singleEntry)
        ? singleEntry.usage
        : null;
    final singleGasRemaining = singleEntry?.gasRemaining;
    final singleGasCost = singleEntry == null
        ? null
        : _dailyGasCost(
            entry: singleEntry,
            purchases: purchases,
            purchaseRepository: purchaseRepository,
          );
    final singleSales = singleEntry?.sales;
    final singleGasPer1000 = gasPer1000Sales(gasUsed: singleGasUsed, sales: singleSales);
    final singleCylinderCount = singleEntry?.connectedCount;
    final singleAddedRemoved = singleEntry == null
        ? null
        : '+${singleEntry.addedCylinders} / -${singleEntry.removedCylinders}';

    final totalUsage = validFilteredEntries.isEmpty
        ? null
        : validFilteredEntries.fold<double>(0, (sum, entry) => sum + entry.usage);
    final averageUsage =
        validFilteredEntries.isEmpty ? null : totalUsage! / validFilteredEntries.length;
    final highestUsageEntry = validFilteredEntries.isEmpty
        ? null
        : validFilteredEntries.reduce((current, next) => next.usage > current.usage ? next : current);
    final lowestUsageEntry = validFilteredEntries.isEmpty
        ? null
        : validFilteredEntries.reduce((current, next) => next.usage < current.usage ? next : current);

    final totalSales = validFilteredEntries.isEmpty
        ? null
        : validFilteredEntries.fold<double>(0, (sum, entry) => sum + entry.sales);
    final gasPer1000ForRange = gasPer1000Sales(gasUsed: totalUsage, sales: totalSales);

    var hasCost = false;
    final totalGasCost = validFilteredEntries.fold<double>(0, (sum, entry) {
      final dailyCost = _dailyGasCost(
        entry: entry,
        purchases: purchases,
        purchaseRepository: purchaseRepository,
      );
      if (dailyCost == null) return sum;
      hasCost = true;
      return sum + dailyCost;
    });

    final totalGasCostValue = hasCost ? totalGasCost : null;
    final accentColor = Theme.of(context).colorScheme.primary;

    final weeklySummary = buildLast7DaysSummary(sortedEntries, today: today);
    var weeklyHasCost = false;
    final weeklyGasCost = weeklySummary.validEntries.fold<double>(0, (sum, entry) {
      final dailyCost = _dailyGasCost(
        entry: entry,
        purchases: purchases,
        purchaseRepository: purchaseRepository,
      );
      if (dailyCost == null) return sum;
      weeklyHasCost = true;
      return sum + dailyCost;
    });

    return SafeArea(
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isFiltering || purchasesAsync.isLoading || entriesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            _buildFilterCard(),
            const SizedBox(height: 18),
            if (filteredEntries.isEmpty || hasRangeError)
              const InsightBanner(
                message: 'No data available for selected period',
                icon: Icons.info_outline,
                textColor: Colors.black87,
                backgroundColor: Color(0xFFF3F4F6),
              )
            else if (treatAsSingle) ...[
              const SectionHeader('Single Date Summary'),
              const SizedBox(height: 16),
              StatCard(
                title: 'Gas Used',
                value: _usageDisplay(singleGasUsed),
                fitValue: true,
                isPrimary: true,
                color: accentColor,
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.55,
                children: [
                  StatCard(
                    title: 'Gas Remaining',
                    value: _usageDisplay(singleGasRemaining),
                    fitValue: true,
                  ),
                  StatCard(title: 'Gas Cost', value: _currencyDisplay(singleGasCost), fitValue: true),
                  StatCard(title: 'Sales', value: _currencyDisplay(singleSales), fitValue: true),
                  StatCard(
                    title: 'Gas per ₹1000 Sales',
                    value: _gasPerThousandDisplay(singleGasPer1000),
                    valueMaxLines: 3,
                  ),
                  StatCard(
                    title: 'Cylinder Count',
                    value: _countDisplay(singleCylinderCount),
                    fitValue: true,
                  ),
                  StatCard(
                    title: 'Added / Removed Cylinders',
                    value: singleAddedRemoved ?? '—',
                    fitValue: true,
                  ),
                ],
              ),
            ] else ...[
              const SectionHeader('Range Summary'),
              const SizedBox(height: 16),
              ResponsiveGrid(
                childAspectRatio: 1.32,
                children: [
                  StatCard(title: 'Total Gas Used', value: _usageDisplay(totalUsage), fitValue: true),
                  StatCard(
                    title: 'Average Daily Usage',
                    value: _usageDisplay(averageUsage),
                    fitValue: true,
                  ),
                  StatCard(
                    title: 'Highest Usage Day',
                    value: _usageDayDisplay(highestUsageEntry),
                    valueMaxLines: 3,
                  ),
                  StatCard(
                    title: 'Lowest Usage Day',
                    value: _usageDayDisplay(lowestUsageEntry),
                    valueMaxLines: 3,
                  ),
                  StatCard(
                    title: 'Total Gas Cost',
                    value: _currencyDisplay(totalGasCostValue),
                    fitValue: true,
                  ),
                  StatCard(title: 'Total Sales', value: _currencyDisplay(totalSales), fitValue: true),
                  StatCard(
                    title: 'Gas per ₹1000 Sales',
                    value: _gasPerThousandDisplay(gasPer1000ForRange),
                    valueMaxLines: 3,
                  ),
                ],
              ),
            ],
            const SizedBox(height: kSectionSpacing),
            const SectionHeader('Last 7 Days Summary'),
            const SizedBox(height: 12),
            ResponsiveGrid(
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: 'Total Gas Used (7 days)',
                  value: _usageDisplay(weeklySummary.totalGasUsed),
                ),
                StatCard(
                  title: 'Average Daily Usage',
                  value: _usageDisplay(weeklySummary.averageDailyUsage),
                ),
                StatCard(
                  title: 'Highest Usage Day',
                  value: _usageDayDisplay(weeklySummary.highestUsageEntry),
                  valueMaxLines: 3,
                ),
                StatCard(
                  title: 'Total Gas Cost (7 days)',
                  value: _currencyDisplay(weeklyHasCost ? weeklyGasCost : null),
                ),
                StatCard(
                  title: 'Total Sales (7 days)',
                  value: _currencyDisplay(weeklySummary.totalSales),
                ),
              ],
            ),
            const SizedBox(height: kSectionSpacing),
          ],
        ),
      ),
    );
  }
}
