import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/purchase.dart';
import 'firestore_service.dart';

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
}
