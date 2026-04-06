import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get dailyEntries =>
      _firestore.collection('daily_entries');

  CollectionReference<Map<String, dynamic>> get purchases =>
      _firestore.collection('purchases');
}
