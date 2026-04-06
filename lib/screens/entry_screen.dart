import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/daily_entry.dart';
import '../providers/app_providers.dart';
import '../utils/date_utils.dart';
import '../utils/gas_calculations.dart';
import '../widgets/dashboard_layout.dart';

class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key});

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salesController = TextEditingController();
  final _otherReasonController = TextEditingController();
  final _addedCylindersController = TextEditingController(text: '0');
  final _removedCylindersController = TextEditingController(text: '0');
  final _scrollController = ScrollController();

  int _connectedCount = 2;
  int _addedCylinders = 0;
  int _removedCylinders = 0;
  String _reason = 'Maintenance';
  DateTime _selectedDate = normalizeDate(DateTime.now());
  bool _isEditingExistingEntry = false;
  bool _isLoadingEntry = false;
  List<TextEditingController> _weightControllers = [];
  List<FocusNode> _weightFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _rebuildWeightFields(_connectedCount);
    _loadEntryForSelectedDate();
  }

  @override
  void dispose() {
    _salesController.dispose();
    _otherReasonController.dispose();
    _addedCylindersController.dispose();
    _removedCylindersController.dispose();
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

  void _populateFormFromEntry(DailyEntry entry) {
    final safeConnectedCount = entry.connectedCount <= 0 ? 1 : entry.connectedCount;
    _connectedCount = safeConnectedCount;
    _rebuildWeightFields(_connectedCount);

    for (var i = 0; i < _connectedCount; i++) {
      final weight = i < entry.weights.length ? entry.weights[i] : null;
      _weightControllers[i].text = weight == null ? '' : weight.toStringAsFixed(2);
    }

    _salesController.text = entry.sales.toStringAsFixed(2);
    _addedCylinders = entry.addedCylinders;
    _removedCylinders = entry.removedCylinders;
    _addedCylindersController.text = _addedCylinders.toString();
    _removedCylindersController.text = _removedCylinders.toString();

    const knownReasons = {'Maintenance', 'Leak Test', 'Operational Change', 'Other'};
    if (knownReasons.contains(entry.changeReason)) {
      _reason = entry.changeReason;
      _otherReasonController.clear();
    } else {
      _reason = 'Other';
      _otherReasonController.text = entry.changeReason;
    }
  }

  void _resetFormForNewEntry() {
    _connectedCount = 2;
    _rebuildWeightFields(_connectedCount);
    _salesController.clear();
    _addedCylinders = 0;
    _removedCylinders = 0;
    _addedCylindersController.text = '0';
    _removedCylindersController.text = '0';
    _reason = 'Maintenance';
    _otherReasonController.clear();
  }

  Future<void> _loadEntryForSelectedDate() async {
    setState(() => _isLoadingEntry = true);
    final entry = await ref.read(dailyEntryRepositoryProvider).getByDate(_selectedDate);
    if (!mounted) return;

    setState(() {
      _isEditingExistingEntry = entry != null;
      if (entry != null) {
        _populateFormFromEntry(entry);
      } else {
        _resetFormForNewEntry();
      }
      _isLoadingEntry = false;
    });
  }

  List<double> _weights() => _weightControllers
      .map((c) => double.tryParse(c.text.trim()) ?? 0)
      .where((w) => w > 0)
      .toList();

  bool get _countChanged => _addedCylinders > 0 || _removedCylinders > 0;
  TextStyle? _labelStyle(BuildContext context) => Theme.of(context).textTheme.titleMedium;
  TextStyle? _valueStyle(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(dailyEntriesProvider).value ?? [];
    final yesterday =
        entries.where((e) => normalizeDate(e.date) == _selectedDate.subtract(const Duration(days: 1))).toList();
    final yesterdayEntry = yesterday.isEmpty ? null : yesterday.first;

    final weights = _weights();
    final grossTotal = calculateGrossTotal(weights);
    final gasRemaining = calculateGasRemaining(weights, _connectedCount);
    final comparableGasRemaining = calculateComparableCurrentGas(
      gasRemaining,
      addedCylinders: _addedCylinders,
      removedCylinders: _removedCylinders,
    );
    final estimatedUsage = yesterdayEntry == null
        ? null
        : calculateUsage(yesterdayEntry.gasRemaining, comparableGasRemaining);

    final statusLabel = _isEditingExistingEntry
        ? 'Editing entry for ${DateFormat.yMMMd().format(_selectedDate)}'
        : 'Creating entry for ${DateFormat.yMMMd().format(_selectedDate)}';

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              kScreenPadding.left,
              kScreenPadding.top,
              kScreenPadding.right,
              kScreenPadding.bottom + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusLabel, style: Theme.of(context).textTheme.titleMedium),
                    if (_isLoadingEntry) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    const SizedBox(height: 12),
                    Text('Date', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = normalizeDate(DateTime.now());
                        final date = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: now,
                          initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
                        );
                        if (date != null) {
                          setState(() => _selectedDate = normalizeDate(date));
                          await _loadEntryForSelectedDate();
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat.yMMMd().format(_selectedDate)),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text('Connected Cylinders', style: Theme.of(context).textTheme.titleMedium),
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
            const SizedBox(height: kSectionSpacing),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            onTap: () {
                              _weightControllers[index].selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _weightControllers[index].text.length,
                              );
                            },
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
            const SizedBox(height: kSectionSpacing),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gas Remaining', style: _labelStyle(context)),
                    const SizedBox(height: 4),
                    Text('${gasRemaining.toStringAsFixed(2)} kg', style: _valueStyle(context)),
                    const SizedBox(height: 2),
                    Text(
                      'Based on cylinder weight minus tare (19.1 kg each)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Yesterday gas remaining: ${yesterdayEntry?.gasRemaining.toStringAsFixed(2) ?? '—'} kg',
                    ),
                    const SizedBox(height: 8),
                    Text('Estimated Usage Today', style: _labelStyle(context)),
                    const SizedBox(height: 4),
                    Text(
                      estimatedUsage == null ? '—' : '${estimatedUsage.toStringAsFixed(2)} kg',
                      style: _valueStyle(context),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Gross total weight: ${grossTotal.toStringAsFixed(2)} kg'),
                    if (_addedCylinders > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+$_addedCylinders cylinder${_addedCylinders == 1 ? '' : 's'} added. Usage adjusted.',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
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
            const SizedBox(height: kSectionSpacing),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cylinder Count Change', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addedCylindersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Added cylinders',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _addedCylinders = int.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _removedCylindersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Removed cylinders',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _removedCylinders = int.tryParse(v) ?? 0),
                    ),
                    if (_countChanged) ...[
                      const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
            const SizedBox(height: kSectionSpacing),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final today = normalizeDate(DateTime.now());
                  if (_selectedDate.isAfter(today)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Future dates are not allowed')),
                    );
                    return;
                  }
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
                    ref.read(currentTabIndexProvider.notifier).state = 0;
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save: $e')),
                    );
                  }
                },
                child: Text(_isEditingExistingEntry ? 'Update Daily Entry' : 'Save Daily Entry'),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
