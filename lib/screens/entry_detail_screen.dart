import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../providers/app_providers.dart';
import '../widgets/dashboard_layout.dart';
import 'entry_screen.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  DailyEntry? _entry;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final entry = await ref.read(dailyEntryRepositoryProvider).getById(widget.entryId);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _isLoading = false;
    });
  }

  Future<void> _deleteEntry() async {
    if (_entry == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('Deleting this entry will recalculate future entries. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(dailyEntryRepositoryProvider).deleteEntryAndRecalculateFuture(_entry!.id);
      ref.invalidate(dailyEntriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Entry deleted. Future entries updated.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _currencyDisplay(double? value) => value == null ? '—' : '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Entry Detail'),
            actions: [
              if (!_isLoading && _entry != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteEntry,
                ),
              if (!_isLoading && _entry != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EntryScreen(
                          initialDate: _entry!.date,
                          lockDate: true,
                          popOnSave: true,
                        ),
                      ),
                    );
                    if (updated == true) {
                      await _loadDetail();
                    }
                  },
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entry == null
                  ? const Center(child: Text('Entry not found'))
                  : ListView(
                      padding: kScreenPadding,
                      children: [
                        _sectionCard(
                          context,
                          title: 'Summary',
                          children: [
                            _row('Date', DateFormat.yMMMd().format(_entry!.date)),
                            _row('Gas Used', '${_entry!.usage.toStringAsFixed(2)} kg'),
                            _row('Gas Remaining', '${_entry!.gasRemaining.toStringAsFixed(2)} kg'),
                            _row('Gas Cost', _currencyDisplay(_entry!.gasCost)),
                            _row('Sales', '₹${_entry!.sales.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          context,
                          title: 'Cylinders',
                          children: [
                            _row('Connected count', _entry!.connectedCount.toString()),
                            _row(
                              'Added / Removed',
                              '+${_entry!.addedCylinders} / -${_entry!.removedCylinders}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          context,
                          title: 'Weights',
                          children: [
                            ..._entry!.weights.asMap().entries.map(
                                  (item) => _row(
                                    'Cylinder ${item.key + 1}',
                                    '${item.value.toStringAsFixed(2)} kg',
                                  ),
                                ),
                            _row('Gross total weight', '${_entry!.grossTotalWeight.toStringAsFixed(2)} kg'),
                            _row('Gas remaining', '${_entry!.gasRemaining.toStringAsFixed(2)} kg'),
                          ],
                        ),
                      ],
                    ),
          bottomNavigationBar: _isLoading || _entry == null
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => EntryScreen(
                            initialDate: _entry!.date,
                            lockDate: true,
                            popOnSave: true,
                          ),
                        ),
                      );
                      if (updated == true) {
                        await _loadDetail();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Entry'),
                  ),
                ),
        ),
        if (_isDeleting) ...[
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

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
