import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../widgets/dashboard_layout.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider).value ?? [];

    return SafeArea(
      child: SingleChildScrollView(
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
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Purchase', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid quantity';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cost per Cylinder',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Enter a valid cost';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: _selectedDate,
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(DateFormat.yMMMd().format(_selectedDate)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            try {
                              await ref.read(purchaseRepositoryProvider).addPurchase(
                                    date: _selectedDate,
                                    quantity: int.parse(_quantityController.text.trim()),
                                    costPerCylinder: double.parse(_costController.text.trim()),
                                  );
                              _quantityController.clear();
                              _costController.clear();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(content: Text('Purchase added')));
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                          child: const Text('Save Purchase'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: kSectionSpacing),
            const SectionHeader('Purchase History'),
            const SizedBox(height: 12),
            ...purchases.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2, right: 8),
                              child: Icon(Icons.propane_tank_outlined, size: 20),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p.quantity} cylinders',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${p.costPerCylinder.toStringAsFixed(2)} each',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '₹${p.totalCost.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DateFormat.yMMMd().format(p.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
