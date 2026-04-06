import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/gas_calculations.dart';

class DailyEntry {
  DailyEntry({
    required this.id,
    required this.date,
    required this.connectedCount,
    required this.weights,
    required this.totalWeight,
    required this.grossTotalWeight,
    required this.gasRemaining,
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
  final double grossTotalWeight;
  final double gasRemaining;
  final double usage;
  final double sales;
  final int addedCylinders;
  final int removedCylinders;
  final String changeReason;
  final bool isAnomaly;

  factory DailyEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final connectedCount = (data['connectedCount'] ?? 0) as int;
    final weights = (data['weights'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();
    final grossTotalWeight = (data['grossTotalWeight'] as num? ??
            data['totalWeight'] as num? ??
            0)
        .toDouble();
    final totalWeight = (data['totalWeight'] as num? ?? grossTotalWeight).toDouble();
    final gasRemaining = (data['gasRemaining'] as num?)?.toDouble() ??
        calculateGasRemaining(weights, connectedCount);

    return DailyEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      connectedCount: connectedCount,
      weights: weights,
      totalWeight: totalWeight,
      grossTotalWeight: grossTotalWeight,
      gasRemaining: gasRemaining,
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
      'grossTotalWeight': grossTotalWeight,
      'gasRemaining': gasRemaining,
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
    double? grossTotalWeight,
    double? gasRemaining,
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
      grossTotalWeight: grossTotalWeight ?? this.grossTotalWeight,
      gasRemaining: gasRemaining ?? this.gasRemaining,
      usage: usage ?? this.usage,
      sales: sales ?? this.sales,
      addedCylinders: addedCylinders ?? this.addedCylinders,
      removedCylinders: removedCylinders ?? this.removedCylinders,
      changeReason: changeReason ?? this.changeReason,
      isAnomaly: isAnomaly ?? this.isAnomaly,
    );
  }
}
