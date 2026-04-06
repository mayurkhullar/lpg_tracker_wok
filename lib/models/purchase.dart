import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  Purchase({
    required this.id,
    required this.date,
    required this.quantity,
    required this.costPerCylinder,
  });

  final String id;
  final DateTime date;
  final int quantity;
  final double costPerCylinder;

  double get totalCost => quantity * costPerCylinder;

  factory Purchase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Purchase(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      quantity: (data['quantity'] ?? 0) as int,
      costPerCylinder: (data['costPerCylinder'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'costPerCylinder': costPerCylinder,
    };
  }
}
