import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase.dart';
import 'costing_service.dart';
import 'firestore_service.dart';


class PurchaseRepository {
  PurchaseRepository(this._service) : _costingService = CostingService(_service);

  final FirestoreService _service;
  final CostingService _costingService;

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
  }) async {
    await _service.purchases.add({
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'costPerCylinder': costPerCylinder,
    });

    await _costingService.recomputeTimeline(recomputeUsage: false);
  }

  Future<void> deletePurchaseAndRecalculate(String id) async {
    await _service.purchases.doc(id).delete();
    await _costingService.recomputeTimeline(recomputeUsage: false);
  }
}
