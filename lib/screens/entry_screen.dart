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
  const EntryScreen({
    super.key,
    this.initialDate,
    this.lockDate = false,
    this.popOnSave = false,
  });

  final DateTime? initialDate;
  final bool lockDate;
  final bool popOnSave;

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
  late DateTime _selectedDate;
  bool _isEditingExistingEntry = false;
  bool _isLoadingEntry = false;
  bool _isSaving = false;
  bool _isRecalculating = false;
  List<TextEditingController> _weightControllers = [];
  List<FocusNode> _weightFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = normalizeDate(widget.initialDate ?? DateTime.now());
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
  bool get _showRecalculationOverlay => _isRecalculating;
  TextStyle? _labelStyle(BuildContext context) => Theme.of(context).textTheme.titleMedium;
  TextStyle? _valueStyle(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
  Widget _summaryMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    String? helper,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _labelStyle(context)?.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: _valueStyle(context)?.copyWith(fontSize: 22)),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inlineNotice({
    required BuildContext context,
    required String message,
    required bool isError,
  }) {
    final bg = isError ? Theme.of(context).colorScheme.errorContainer : Colors.orange.withValues(alpha: 0.1);
    final fg = isError ? Theme.of(context).colorScheme.onErrorContainer : Colors.orange.shade900;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.warning_amber_rounded, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: isError ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  double? _sevenDayAverageUsageForDate(List<DailyEntry> entries, DateTime selectedDate) {
    final usageValues = entries
        .where((entry) => normalizeDate(entry.date).isBefore(selectedDate))
        .map((entry) => entry.usage)
        .where((usage) => usage > 0)
        .take(7)
        .toList();
    if (usageValues.isEmpty) return null;
    final total = usageValues.fold<double>(0, (sum, usage) => sum + usage);
    return total / usageValues.length;
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    final today = normalizeDate(DateTime.now());
    if (_selectedDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Future dates are not allowed')),
      );
      return;
    }

    final repository = ref.read(dailyEntryRepositoryProvider);
    final sales = double.parse(_salesController.text.trim());
    final changeReason = _reason == 'Other' ? _otherReasonController.text.trim() : _reason;
    final entries = ref.read(dailyEntriesProvider).value ?? [];
    final previousEntry = entries
        .where((entry) => normalizeDate(entry.date).isBefore(_selectedDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final yesterdayEntry = previousEntry.isEmpty ? null : previousEntry.first;

    final gasRemaining = calculateGasRemaining(_weights(), _connectedCount);
    final avgUsage = _sevenDayAverageUsageForDate(entries, _selectedDate);
    final usageValidation = yesterdayEntry == null
        ? null
        : calculateDailyUsageWithWarnings(
            yesterdayEntry.gasRemaining,
            gasRemaining,
            addedCylinders: _addedCylinders,
            removedCylinders: _removedCylinders,
            sevenDayAverageUsage: avgUsage,
          );

    if (usageValidation != null && usageValidation.blockingErrors.isNotEmpty) {
      for (final error in usageValidation.blockingErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditingExistingEntry && widget.lockDate) {
        setState(() => _isRecalculating = true);
        await repository.updateEntryAndRecalculateFuture(
          id: dayId(_selectedDate),
          connectedCount: _connectedCount,
          weights: _weights(),
          sales: sales,
          addedCylinders: _addedCylinders,
          removedCylinders: _removedCylinders,
          changeReason: changeReason,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Future entries updated')),
        );
      } else {
        await repository.saveDailyEntry(
          date: _selectedDate,
          connectedCount: _connectedCount,
          weights: _weights(),
          sales: sales,
          addedCylinders: _addedCylinders,
          removedCylinders: _removedCylinders,
          changeReason: changeReason,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully')),
        );
      }

      if (usageValidation != null && usageValidation.warnings.isNotEmpty) {
        for (final warning in usageValidation.warnings) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(warning),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (!mounted) return;
      if (widget.popOnSave) {
        Navigator.of(context).pop(true);
      } else {
        ref.read(currentTabIndexProvider.notifier).state = 0;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isRecalculating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(dailyEntriesProvider).value ?? [];
    final yesterday =
        entries.where((e) => normalizeDate(e.date) == _selectedDate.subtract(const Duration(days: 1))).toList();
    final yesterdayEntry = yesterday.isEmpty ? null : yesterday.first;

    final weights = _weights();
    final grossTotal = calculateGrossTotal(weights);
    final gasRemaining = calculateGasRemaining(weights, _connectedCount);
    final estimatedUsage = yesterdayEntry == null
        ? null
        : calculateDailyUsageWithWarnings(
            yesterdayEntry.gasRemaining,
            gasRemaining,
            addedCylinders: _addedCylinders,
            removedCylinders: _removedCylinders,
            sevenDayAverageUsage: _sevenDayAverageUsageForDate(entries, _selectedDate),
          );

    final statusLabel = _isEditingExistingEntry
        ? 'Editing entry for ${DateFormat.yMMMd().format(_selectedDate)}'
        : 'Creating entry for ${DateFormat.yMMMd().format(_selectedDate)}';

    return Scaffold(
      appBar: widget.lockDate
          ? AppBar(
              title: const Text('Edit Entry'),
            )
          : null,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveEntry,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditingExistingEntry ? 'Update Daily Entry' : 'Save Daily Entry'),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  kScreenPadding.left,
                  kScreenPadding.top,
                  kScreenPadding.right,
                  kScreenPadding.bottom + MediaQuery.of(context).viewInsets.bottom + 90,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Basic Info'),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusLabel, style: Theme.of(context).textTheme.titleSmall),
                            if (_isLoadingEntry) ...[
                              const SizedBox(height: 6),
                              const LinearProgressIndicator(minHeight: 2),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Date',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                                      const SizedBox(height: 6),
                                      OutlinedButton.icon(
                                        onPressed: widget.lockDate
                                            ? null
                                            : () async {
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
                                        icon: const Icon(Icons.calendar_today, size: 18),
                                        label: Text(DateFormat.yMMMd().format(_selectedDate)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Connected',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
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
                                          visualDensity: VisualDensity.compact,
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: kSectionSpacing),
                    const SectionHeader('Weights'),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cylinder Weights (kg)', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ...List.generate(_connectedCount, (index) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: index == _connectedCount - 1 ? 0 : 8),
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
                                      isDense: true,
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
                    const SectionHeader('Quick Summary'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryMetricCard(
                            context: context,
                            title: 'Gas Remaining',
                            value: '${gasRemaining.toStringAsFixed(2)} kg',
                            helper: 'After tare deduction',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _summaryMetricCard(
                            context: context,
                            title: 'Estimated Usage',
                            value: estimatedUsage == null ? '—' : '${estimatedUsage.usage.toStringAsFixed(2)} kg',
                            helper: 'Usage for today',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yesterday gas remaining: ${yesterdayEntry?.gasRemaining.toStringAsFixed(2) ?? '—'} kg',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gross total weight: ${grossTotal.toStringAsFixed(2)} kg',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (estimatedUsage != null && estimatedUsage.blockingErrors.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...estimatedUsage.blockingErrors.map(
                                (error) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _inlineNotice(context: context, message: error, isError: true),
                                ),
                              ),
                            ],
                            if (estimatedUsage != null && estimatedUsage.warnings.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...estimatedUsage.warnings.map(
                                (warning) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _inlineNotice(context: context, message: warning, isError: false),
                                ),
                              ),
                            ],
                            if (_addedCylinders > 0) ...[
                              const SizedBox(height: 6),
                              _inlineNotice(
                                context: context,
                                message:
                                    '+$_addedCylinders cylinder${_addedCylinders == 1 ? '' : 's'} added. Usage adjusted.',
                                isError: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: kSectionSpacing),
                    const SectionHeader('Operational Details'),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _salesController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                labelText: 'Sales',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (value) {
                                final d = double.tryParse(value ?? '');
                                if (d == null) return 'Enter a valid sales value';
                                if (d < 0) return 'Cannot be negative';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Text('Cylinder Count Change', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _addedCylindersController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Added cylinders',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _addedCylinders = int.tryParse(v) ?? 0),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _removedCylindersController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Removed cylinders',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _removedCylinders = int.tryParse(v) ?? 0),
                            ),
                            if (_countChanged) ...[
                              const SizedBox(height: 8),
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
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() => _reason = v ?? 'Maintenance'),
                              ),
                              if (_reason == 'Other') ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _otherReasonController,
                                  decoration: const InputDecoration(
                                    labelText: 'Other reason',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showRecalculationOverlay)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      SizedBox(height: 10),
                      Text('Updating future entries...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
