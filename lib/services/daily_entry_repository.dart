import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_entry.dart';
import '../utils/date_utils.dart';
import 'firestore_service.dart';

class DailyEntryRepository {
  DailyEntryRepository(this._service);

  final FirestoreService _service;

  Stream<List<DailyEntry>> watchEntries({int limit = 120}) {
    return _service.dailyEntries
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(DailyEntry.fromDoc).toList());
  }

  Future<List<DailyEntry>> fetchAll({int limit = 365}) async {
    final snap = await _service.dailyEntries
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(DailyEntry.fromDoc).toList();
  }

  Future<DailyEntry?> getByDate(DateTime date) async {
    final id = dayId(date);
    final doc = await _service.dailyEntries.doc(id).get();
    if (!doc.exists) return null;
    return DailyEntry.fromDoc(doc);
  }

  Future<DailyEntry?> getPrevious(DateTime date) async {
    final snap = await _service.dailyEntries
        .where('date', isLessThan: Timestamp.fromDate(normalizeDate(date)))
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return DailyEntry.fromDoc(snap.docs.first);
  }

  Future<void> saveDailyEntry({
    required DateTime date,
    required int connectedCount,
    required List<double> weights,
    required double sales,
    required int addedCylinders,
    required int removedCylinders,
    required String changeReason,
  }) async {
    final targetDate = normalizeDate(date);
    final today = normalizeDate(DateTime.now());
    if (targetDate.isAfter(today)) {
      throw ArgumentError('Future dates are not allowed');
    }
    final todayId = dayId(targetDate);

    final previous = await getPrevious(targetDate);
    final totalWeight = weights.fold<double>(0, (total, e) => total + e);

    final adjustmentRefWeight =
        weights.isEmpty ? 28.0 : (totalWeight / weights.length).clamp(19.1, 38.0);
    final adjustedTodayComparable =
        totalWeight - (addedCylinders * adjustmentRefWeight) + (removedCylinders * adjustmentRefWeight);

    final daysDiff = previous == null ? 1 : targetDate.difference(normalizeDate(previous.date)).inDays;
    final usageAcrossGap = previous == null ? 0.0 : math.max(0, previous.totalWeight - adjustedTodayComparable);
    final distributedUsage = daysDiff <= 0 ? 0.0 : usageAcrossGap / daysDiff;

    final newEntry = DailyEntry(
      id: todayId,
      date: targetDate,
      connectedCount: connectedCount,
      weights: weights,
      totalWeight: totalWeight,
      usage: distributedUsage,
      sales: sales,
      addedCylinders: addedCylinders,
      removedCylinders: removedCylinders,
      changeReason: changeReason,
      isAnomaly: false,
    );

    final batch = FirebaseFirestore.instance.batch();
    batch.set(_service.dailyEntries.doc(todayId), newEntry.toMap(), SetOptions(merge: true));

    if (previous != null && daysDiff > 1) {
      for (var i = 1; i < daysDiff; i++) {
        final missedDate = normalizeDate(previous.date).add(Duration(days: i));
        final id = dayId(missedDate);
        final estimatedTotal = previous.totalWeight - (distributedUsage * i);
        final missed = DailyEntry(
          id: id,
          date: missedDate,
          connectedCount: previous.connectedCount,
          weights: const [],
          totalWeight: estimatedTotal,
          usage: distributedUsage,
          sales: 0,
          addedCylinders: 0,
          removedCylinders: 0,
          changeReason: 'Auto-distributed due to missed entry',
          isAnomaly: false,
        );
        batch.set(_service.dailyEntries.doc(id), missed.toMap(), SetOptions(merge: true));
      }
    }

    await batch.commit();
    await _recomputeAnomalies();
  }

  Future<void> _recomputeAnomalies() async {
    final entries = (await fetchAll(limit: 400)).reversed.toList();
    if (entries.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < entries.length; i++) {
      final history = entries
          .sublist(math.max(0, i - 14), i)
          .map((e) => e.usage)
          .where((u) => u > 0)
          .toList();
      bool anomaly = false;
      if (history.length >= 7) {
        final mean = history.reduce((a, b) => a + b) / history.length;
        final variance = history.fold<double>(0, (acc, u) => acc + math.pow(u - mean, 2)) /
            history.length;
        final sd = math.sqrt(variance);
        anomaly = entries[i].usage > (mean + sd);
      }

      if (entries[i].isAnomaly != anomaly) {
        batch.update(_service.dailyEntries.doc(entries[i].id), {'isAnomaly': anomaly});
      }
    }

    await batch.commit();
  }

  Future<bool> hasPendingWrites() async {
    final snap = await _service.dailyEntries.limit(1).get(const GetOptions(source: Source.cache));
    return snap.metadata.hasPendingWrites;
  }
}
