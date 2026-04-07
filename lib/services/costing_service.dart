import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_entry.dart';
import '../models/purchase.dart';
import '../utils/date_utils.dart';
import '../utils/gas_calculations.dart';
import 'firestore_service.dart';

class CostingService {
  CostingService(this._service);

  final FirestoreService _service;

  Future<void> recomputeTimeline({required bool recomputeUsage}) async {
    final entriesSnap = await _service.dailyEntries.orderBy('date', descending: false).get();
    if (entriesSnap.docs.isEmpty) return;

    final purchasesSnap = await _service.purchases.orderBy('date', descending: false).get();
    final entries = entriesSnap.docs.map(DailyEntry.fromDoc).toList();
    final purchases = purchasesSnap.docs.map(Purchase.fromDoc).toList();

    var currentStockKg = 0.0;
    var currentAvgCostPerKg = 0.0;
    var purchaseIndex = 0;
    DailyEntry? previousEntry;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    var pendingOps = 0;

    Future<void> flushBatch() async {
      if (pendingOps == 0) return;
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      pendingOps = 0;
    }

    for (final entry in entries) {
      final entryDate = normalizeDate(entry.date);
      while (purchaseIndex < purchases.length &&
          !normalizeDate(purchases[purchaseIndex].date).isAfter(entryDate)) {
        final purchase = purchases[purchaseIndex];
        final purchasedGasKg = purchase.quantity * kMaxGasContentPerCylinderKg;
        final purchaseTotalCost = purchase.quantity * purchase.costPerCylinder;

        if (purchasedGasKg > 0) {
          final denominator = currentStockKg + purchasedGasKg;
          if (denominator > 0) {
            currentAvgCostPerKg =
                ((currentStockKg * currentAvgCostPerKg) + purchaseTotalCost) / denominator;
          } else {
            currentAvgCostPerKg = purchase.costPerCylinder / kMaxGasContentPerCylinderKg;
          }
          currentStockKg += purchasedGasKg;
        }

        purchaseIndex++;
      }

      final usage = recomputeUsage
          ? (previousEntry == null
              ? 0.0
              : calculateDailyUsage(
                  previousEntry.gasRemaining,
                  entry.gasRemaining,
                  addedCylinders: entry.addedCylinders,
                ))
          : entry.usage;

      final gasCost = currentAvgCostPerKg > 0 ? usage * currentAvgCostPerKg : null;
      currentStockKg = math.max(0, currentStockKg - usage);

      final updates = <String, dynamic>{
        'avgCostPerKg': currentAvgCostPerKg,
        if (gasCost != null) 'gasCost': gasCost else 'gasCost': FieldValue.delete(),
      };

      if (recomputeUsage) {
        updates['usage'] = usage;
      }

      batch.set(_service.dailyEntries.doc(entry.id), updates, SetOptions(merge: true));
      pendingOps++;
      previousEntry = entry.copyWith(usage: usage);

      if (pendingOps >= 350) {
        await flushBatch();
      }
    }

    await flushBatch();
  }
}
