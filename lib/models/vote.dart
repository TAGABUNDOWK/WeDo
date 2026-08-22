import 'package:cloud_firestore/cloud_firestore.dart';

class Vote {
  final String id;
  final String option;
  final String? uid;
  final String? voterHash;
  final DateTime createdAt;

  const Vote({
    required this.id,
    required this.option,
    this.uid,
    this.voterHash,
    required this.createdAt,
  });

  factory Vote.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Vote(
      id: doc.id,
      option: data['option'] as String? ?? '',
      uid: data['uid'] as String?,
      voterHash: data['voterHash'] as String?,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'option': option,
      if (uid != null) 'uid': uid,
      if (voterHash != null) 'voterHash': voterHash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
 