import 'package:cloud_firestore/cloud_firestore.dart';

class DailyEntry {
  DailyEntry({
    required this.id,
    required this.date,
    required this.connectedCount,
    required this.weights,
    required this.totalWeight,
    required this.usage,
    required this.sales,
    required this.addedCylinders,
    required this.removedCylinders,
    required this.changeReason,
    required this.isAnomaly,
  });

  final String id;
  final DateTime date;
  final int connectedCount;
  final List<double> weights;
  final double totalWeight;
  final double usage;
  final double sales;
  final int addedCylinders;
  final int removedCylinders;
  final String changeReason;
  final bool isAnomaly;

  factory DailyEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DailyEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      connectedCount: (data['connectedCount'] ?? 0) as int,
      weights: (data['weights'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      totalWeight: (data['totalWeight'] as num? ?? 0).toDouble(),
      usage: (data['usage'] as num? ?? 0).toDouble(),
      sales: (data['sales'] as num? ?? 0).toDouble(),
      addedCylinders: (data['addedCylinders'] ?? 0) as int,
      removedCylinders: (data['removedCylinders'] ?? 0) as int,
      changeReason: (data['changeReason'] ?? '') as String,
      isAnomaly: (data['isAnomaly'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'connectedCount': connectedCount,
      'weights': weights,
      'totalWeight': totalWeight,
      'usage': usage,
      'sales': sales,
      'addedCylinders': addedCylinders,
      'removedCylinders': removedCylinders,
      'changeReason': changeReason,
      'isAnomaly': isAnomaly,
    };
  }

  DailyEntry copyWith({
    String? id,
    DateTime? date,
    int? connectedCount,
    List<double>? weights,
    double? totalWeight,
    double? usage,
    double? sales,
    int? addedCylinders,
    int? removedCylinders,
    String? changeReason,
    bool? isAnomaly,
  }) {
    return DailyEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      connectedCount: connectedCount ?? this.connectedCount,
      weights: weights ?? this.weights,
      totalWeight: totalWeight ?? this.totalWeight,
      usage: usage ?? this.usage,
      sales: sales ?? this.sales,
      addedCylinders: addedCylinders ?? this.addedCylinders,
      removedCylinders: removedCylinders ?? this.removedCylinders,
      changeReason: changeReason ?? this.changeReason,
      isAnomaly: isAnomaly ?? this.isAnomaly,
    );
  }
}
