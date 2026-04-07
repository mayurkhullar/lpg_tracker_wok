import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_entry.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/entry_summary_card.dart';
import 'entry_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  bool _isProcessingDelete = false;
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

  String _currencyDisplay(double? value) => value == null ? '—' : '₹${value.toStringAsFixed(2)}';

  Future<void> _deleteEntry(DailyEntry entry) async {
    if (_isProcessingDelete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
          'Deleting this entry will recalculate future entries. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessingDelete = true);
    try {
      await ref.read(dailyEntryRepositoryProvider).deleteEntryAndRecalculateFuture(entry.id);
      ref.invalidate(dailyEntriesProvider);
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted. Future entries updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isProcessingDelete = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthAverage = _entries.isEmpty
        ? null
        : _entries.fold<double>(0, (sum, entry) => sum + entry.usage) / _entries.length;

    return Stack(
      children: [
        SafeArea(
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
                                final hasMovement =
                                    entry.addedCylinders != 0 || entry.removedCylinders != 0;

                                return EntrySummaryCard(
                                  date: entry.date,
                                  gasUsedText: '${entry.usage.toStringAsFixed(2)} kg',
                                  gasCostText: _currencyDisplay(entry.gasCost),
                                  salesText: _currencyDisplay(entry.sales),
                                  gasUsedColor: _getUsageColor(
                                    context: context,
                                    usage: entry.usage,
                                    average: monthAverage,
                                  ),
                                  movementText: hasMovement
                                      ? '+${entry.addedCylinders} / -${entry.removedCylinders}'
                                      : null,
                                  onTap: () async {
                                    final changed = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => EntryDetailScreen(entryId: entry.id),
                                      ),
                                    );
                                    if (changed == true && mounted) {
                                      await _loadHistory();
                                    }
                                  },
                                  onDelete: () => _deleteEntry(entry),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
        if (_isProcessingDelete) ...[
          const ModalBarrier(dismissible: false, color: Colors.black38),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Updating entries...'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getUsageColor({
    required BuildContext context,
    required double usage,
    required double? average,
  }) {
    if (average == null || average <= 0) return Theme.of(context).colorScheme.onSurface;
    if (usage > average * 1.3) return Colors.orange.shade700;
    if (usage < average * 0.7) return Colors.green.shade700;
    return Theme.of(context).colorScheme.onSurface;
  }
}
