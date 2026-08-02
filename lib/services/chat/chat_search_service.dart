import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message.dart';
import '../../utils/constants.dart';

class ChatSearchService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<ChatMessage>> searchGroupMessages({
    required String groupId,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
    String? textQuery,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection);

    if (senderId != null) {
      query = query.where('senderId', isEqualTo: senderId);
    }

    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
      );
    }

    final snap = await query.orderBy('createdAt', descending: true).limit(limit).get();
    var messages = snap.docs.map(ChatMessage.fromFirestore).toList();

    if (textQuery != null && textQuery.isNotEmpty) {
      final lower = textQuery.toLowerCase();
      messages = messages.where((m) => m.content.toLowerCase().contains(lower)).toList();
    }

    return messages;
  }
}
