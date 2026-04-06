import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../utils/date_utils.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salesController = TextEditingController();
  final _otherReasonController = TextEditingController();
  final _scrollController = ScrollController();

  int _connectedCount = 2;
  int _addedCylinders = 0;
  int _removedCylinders = 0;
  String _reason = 'Maintenance';
  DateTime _selectedDate = normalizeDate(DateTime.now());
  List<TextEditingController> _weightControllers = [];
  List<FocusNode> _weightFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _rebuildWeightFields(_connectedCount);
  }

  @override
  void dispose() {
    _salesController.dispose();
    _otherReasonController.dispose();
    _scrollController.dispose();
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final f in _weightFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _rebuildWeightFields(int count) {
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final f in _weightFocusNodes) {
      f.dispose();
    }
    _weightControllers = List.generate(count, (_) => TextEditingController());
    _weightFocusNodes = List.generate(count, (_) => FocusNode());
  }

  List<double> _weights() => _weightControllers
      .map((c) => double.tryParse(c.text.trim()) ?? 0)
      .where((w) => w > 0)
      .toList();

  bool get _countChanged => _addedCylinders > 0 || _removedCylinders > 0;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(dailyEntriesProvider).value ?? [];
    final yesterday = entries.where((e) => normalizeDate(e.date) == _selectedDate.subtract(const Duration(days: 1))).toList();
    final yesterdayEntry = yesterday.isEmpty ? null : yesterday.first;

    final totalWeight = _weights().fold<double>(0, (sum, e) => sum + e);
    final estimatedUsage = yesterdayEntry == null ? 0.0 : (yesterdayEntry.totalWeight - totalWeight).clamp(0, 9999);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: _selectedDate,
                        );
                        if (date != null) setState(() => _selectedDate = normalizeDate(date));
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat.yMMMd().format(_selectedDate)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Connected Cylinders', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          onPressed: _connectedCount > 1
                              ? () {
                                  setState(() {
                                    _connectedCount--;
                                    _rebuildWeightFields(_connectedCount);
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_connectedCount', style: Theme.of(context).textTheme.titleLarge),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _connectedCount++;
                              _rebuildWeightFields(_connectedCount);
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cylinder Weights (kg)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...List.generate(_connectedCount, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: _weightControllers[index],
                            focusNode: _weightFocusNodes[index],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction:
                                index == _connectedCount - 1 ? TextInputAction.done : TextInputAction.next,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            autofocus: index == 0,
                            onChanged: (_) => setState(() {}),
                            onFieldSubmitted: (_) {
                              if (index < _connectedCount - 1) {
                                _weightFocusNodes[index + 1].requestFocus();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Cylinder ${index + 1} weight',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final weight = double.tryParse(value ?? '');
                              if (weight == null) return 'Required';
                              if (weight < 19.1 || weight > 38) {
                                return 'Weight must be between 19.1 and 38';
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yesterday total: ${yesterdayEntry?.totalWeight.toStringAsFixed(2) ?? '--'} kg'),
                    const SizedBox(height: 6),
                    Text('Live total: ${totalWeight.toStringAsFixed(2)} kg'),
                    const SizedBox(height: 6),
                    Text('Estimated usage: ${estimatedUsage.toStringAsFixed(2)} kg'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _salesController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Sales',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final d = double.tryParse(value ?? '');
                        if (d == null) return 'Enter a valid sales value';
                        if (d < 0) return 'Cannot be negative';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cylinder Count Change', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: '0',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Added cylinders',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _addedCylinders = int.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: '0',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Removed cylinders',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _removedCylinders = int.tryParse(v) ?? 0),
                    ),
                    if (_countChanged) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _reason,
                        items: const [
                          DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                          DropdownMenuItem(value: 'Leak Test', child: Text('Leak Test')),
                          DropdownMenuItem(value: 'Operational Change', child: Text('Operational Change')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Change reason',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _reason = v ?? 'Maintenance'),
                      ),
                      if (_reason == 'Other') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _otherReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Other reason',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              try {
                await ref.read(dailyEntryRepositoryProvider).saveDailyEntry(
                      date: _selectedDate,
                      connectedCount: _connectedCount,
                      weights: _weights(),
                      sales: double.parse(_salesController.text.trim()),
                      addedCylinders: _addedCylinders,
                      removedCylinders: _removedCylinders,
                      changeReason: _reason == 'Other' ? _otherReasonController.text.trim() : _reason,
                    );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Entry saved successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save: $e')),
                );
              }
            },
            child: const Text('Save Daily Entry'),
          ),
        ),
      ),
    );
  }
}
