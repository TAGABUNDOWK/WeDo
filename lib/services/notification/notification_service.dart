import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_entity.dart';
import '../../utils/constants.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userNotifications(String userId) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.notificationsCollection);
  }

  Future<void> createNotification(
      String userId, NotificationEntity notification) async {
    await _userNotifications(userId).add(notification.toMap());
  }

  Stream<List<NotificationEntity>> getNotificationsStream(String userId) {
    return _userNotifications(userId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => NotificationEntity.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<int> getUnreadCount(String userId) {
    return _userNotifications(userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _userNotifications(userId).doc(notificationId).update({
      'is_read': true,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _userNotifications(userId)
        .where('is_read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
