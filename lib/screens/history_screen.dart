import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../models/purchase.dart';
import '../providers/app_providers.dart';
import '../services/purchase_repository.dart';
import '../utils/date_utils.dart';
import '../widgets/dashboard_layout.dart';
import 'entry_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  List<DailyEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final today = normalizeDate(DateTime.now());
    final start = today.subtract(const Duration(days: 29));
    final entries = await ref.read(dailyEntryRepositoryProvider).fetchEntriesInRange(
          start: start,
          end: today,
        );
    if (!mounted) return;
    setState(() {
      _entries = [...entries]..sort((a, b) => b.date.compareTo(a.date));
      _isLoading = false;
    });
  }

  String _currencyDisplay(double value) => '₹${value.toStringAsFixed(2)}';

  double? _dailyGasCost({
    required DailyEntry entry,
    required List<Purchase> purchases,
    required PurchaseRepository purchaseRepository,
  }) {
    final costPerCylinder = purchaseRepository.resolveCostPerCylinderForDate(entry.date, purchases);
    if (costPerCylinder == null) return null;
    return entry.usage * (costPerCylinder / gasPerCylinder);
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider).value ?? [];
    final purchaseRepository = ref.watch(purchaseRepositoryProvider);

    return SafeArea(
      child: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No history in last 30 days.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: kScreenPadding,
                          itemCount: _entries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            final gasCost = _dailyGasCost(
                              entry: entry,
                              purchases: purchases,
                              purchaseRepository: purchaseRepository,
                            );
                            final hasMovement = entry.addedCylinders != 0 || entry.removedCylinders != 0;

                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EntryDetailScreen(entryId: entry.id),
                                    ),
                                  );
                                },
                                title: Text(DateFormat.yMMMd().format(entry.date)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Gas Used: ${entry.usage.toStringAsFixed(2)} kg'),
                                    Text('Gas Cost: ${gasCost == null ? '—' : _currencyDisplay(gasCost)}'),
                                    Text('Sales: ${_currencyDisplay(entry.sales)}'),
                                    if (hasMovement) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '+${entry.addedCylinders} / -${entry.removedCylinders}',
                                          style: Theme.of(context).textTheme.labelMedium,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
