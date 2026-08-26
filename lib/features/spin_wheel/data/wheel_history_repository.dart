import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wheel_option.dart';
import '../models/wheel_spin_record.dart';

class WheelHistoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _historyRef {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('wheelHistory');
  }

  Future<void> saveSpin({
    required List<WheelOption> options,
    required WheelOption winningOption,
    required int winningIndex,
  }) async {
    final ref = _historyRef;
    if (ref == null) return;

    final record = WheelSpinRecord(
      id: '',
      options: options,
      winningOption: winningOption,
      winningIndex: winningIndex,
      timestamp: DateTime.now(),
    );

    await ref.add(record.toFirestore());
  }

  Stream<List<WheelSpinRecord>> getHistoryStream() {
    final ref = _historyRef;
    if (ref == null) {
      return Stream.value([]);
    }

    return ref
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WheelSpinRecord.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> deleteSpin(String spinId) async {
    final ref = _historyRef;
    if (ref == null) return;
    await ref.doc(spinId).delete();
  }
}
