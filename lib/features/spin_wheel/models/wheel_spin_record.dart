import 'package:cloud_firestore/cloud_firestore.dart';
import 'wheel_option.dart';

class WheelSpinRecord {
  final String id;
  final List<WheelOption> options;
  final WheelOption winningOption;
  final int winningIndex;
  final DateTime timestamp;

  const WheelSpinRecord({
    required this.id,
    required this.options,
    required this.winningOption,
    required this.winningIndex,
    required this.timestamp,
  });

  int get optionCount => options.length;

  Map<String, dynamic> toFirestore() {
    return {
      'options': options.map((o) => o.toMap()).toList(),
      'winningOption': winningOption.toMap(),
      'winningIndex': winningIndex,
      'timestamp': FieldValue.serverTimestamp(),
      'optionCount': optionCount,
    };
  }

  factory WheelSpinRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final options = (data['options'] as List)
        .map((o) => WheelOption.fromMap(o as Map<String, dynamic>))
        .toList();
    final winningOption =
        WheelOption.fromMap(data['winningOption'] as Map<String, dynamic>);
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return WheelSpinRecord(
      id: doc.id,
      options: options,
      winningOption: winningOption,
      winningIndex: data['winningIndex'] as int,
      timestamp: timestamp,
    );
  }
}
