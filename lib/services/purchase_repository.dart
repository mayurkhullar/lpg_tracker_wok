import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase.dart';
import '../utils/date_utils.dart';
import 'firestore_service.dart';

const double gasPerCylinder = 18.9;

class PurchaseRepository {
  PurchaseRepository(this._service);

  final FirestoreService _service;

  Stream<List<Purchase>> watchPurchases() {
    return _service.purchases
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Purchase.fromDoc).toList());
  }

  Future<void> addPurchase({
    required DateTime date,
    required int quantity,
    required double costPerCylinder,
  }) {
    return _service.purchases.add({
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'costPerCylinder': costPerCylinder,
    });
  }

  Future<double?> getCostPerCylinderForDate(DateTime date) async {
    final targetDate = normalizeDate(date);
    final dayStart = Timestamp.fromDate(targetDate);
    final dayEnd = Timestamp.fromDate(targetDate.add(const Duration(days: 1)));

    final sameDaySnap = await _service.purchases
        .where('date', isGreaterThanOrEqualTo: dayStart)
        .where('date', isLessThan: dayEnd)
        .get();

    if (sameDaySnap.docs.isNotEmpty) {
      final sameDayPurchases = sameDaySnap.docs.map(Purchase.fromDoc).toList();
      final totalCost =
          sameDayPurchases.fold<double>(0, (total, purchase) => total + purchase.costPerCylinder);
      return totalCost / sameDayPurchases.length;
    }

    final previousSnap = await _service.purchases
        .where('date', isLessThan: dayStart)
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (previousSnap.docs.isEmpty) return null;
    return Purchase.fromDoc(previousSnap.docs.first).costPerCylinder;
  }

  double? resolveCostPerCylinderForDate(DateTime date, List<Purchase> purchases) {
    if (purchases.isEmpty) return null;
    final targetDate = normalizeDate(date);

    final sameDayPurchases = purchases
        .where((purchase) => normalizeDate(purchase.date) == targetDate)
        .toList();
    if (sameDayPurchases.isNotEmpty) {
      final totalCost =
          sameDayPurchases.fold<double>(0, (total, purchase) => total + purchase.costPerCylinder);
      return totalCost / sameDayPurchases.length;
    }

    final sortedPurchases = [...purchases]..sort((a, b) => a.date.compareTo(b.date));
    Purchase? latestBefore;
    for (final purchase in sortedPurchases) {
      if (normalizeDate(purchase.date).isBefore(targetDate)) {
        latestBefore = purchase;
      } else {
        break;
      }
    }
    return latestBefore?.costPerCylinder;
  }
}
