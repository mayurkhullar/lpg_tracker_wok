import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_entry.dart';
import '../models/purchase.dart';
import '../services/daily_entry_repository.dart';
import '../services/firestore_service.dart';
import '../services/purchase_repository.dart';

enum SyncStatus { offline, syncing, synced }

final firebaseInitProvider = FutureProvider<FirebaseApp>((ref) async {
  return Firebase.initializeApp();
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: true);
  return firestore;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

final dailyEntryRepositoryProvider = Provider<DailyEntryRepository>((ref) {
  return DailyEntryRepository(ref.watch(firestoreServiceProvider));
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(firestoreServiceProvider));
});

final dailyEntriesProvider = StreamProvider<List<DailyEntry>>((ref) {
  return ref.watch(dailyEntryRepositoryProvider).watchEntries(limit: 180);
});

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchases();
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final connectivity = Connectivity();
  await for (final result in connectivity.onConnectivityChanged) {
    final isOffline = result.contains(ConnectivityResult.none);
    if (isOffline) {
      yield SyncStatus.offline;
      continue;
    }

    final pending = await ref.watch(dailyEntryRepositoryProvider).hasPendingWrites();
    yield pending ? SyncStatus.syncing : SyncStatus.synced;
  }
});
