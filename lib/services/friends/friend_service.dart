import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/friend_entity.dart';
import '../../models/notification_entity.dart';
import '../../models/user_entity.dart';
import '../notification/notification_service.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  static String friendshipId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  Future<void> sendRequest(String currentUid, String targetUid) async {
    final ids = [currentUid, targetUid]..sort();
    final id = friendshipId(currentUid, targetUid);
    await _db.collection('friends').doc(id).set({
      'userIds': ids,
      'status': 'pending',
      'requestedBy': currentUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final senderDoc = await _db.collection('users').doc(currentUid).get();
    final senderData = senderDoc.data();
    final senderName = senderData?['display_name'] as String? ??
        senderData?['username'] as String? ??
        'Someone';

    await _notificationService.createNotification(
      targetUid,
      NotificationEntity(
        notificationId: '',
        type: NotificationType.friendRequest,
        title: 'Friend Request',
        message: '$senderName sent you a friend request',
        senderId: currentUid,
        relatedId: id,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> acceptRequest(String friendshipId,
      {String? acceptorUid, String? acceptorNotificationId}) async {
    await _db.collection('friends').doc(friendshipId).update({
      'status': 'friends',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (acceptorUid != null && acceptorNotificationId != null) {
      await _notificationService.updateNotificationStatus(
        acceptorUid,
        acceptorNotificationId,
        NotificationStatus.accepted,
      );
    }

    final friendshipDoc =
        await _db.collection('friends').doc(friendshipId).get();
    final friendshipData = friendshipDoc.data();
    if (friendshipData == null) return;

    final userIds = (friendshipData['userIds'] as List?)?.cast<String>() ?? [];
    final requestedBy = friendshipData['requestedBy'] as String?;
    if (requestedBy == null || userIds.length != 2) return;

    final acceptorId = userIds.firstWhere((id) => id != requestedBy);

    final acceptorDoc = await _db.collection('users').doc(acceptorId).get();
    final acceptorData = acceptorDoc.data();
    final acceptorName = acceptorData?['display_name'] as String? ??
        acceptorData?['username'] as String? ??
        'Someone';

    await _notificationService.createNotification(
      requestedBy,
      NotificationEntity(
        notificationId: '',
        type: NotificationType.friendRequestAccepted,
        title: 'Friend Request Accepted',
        message: '$acceptorName accepted your friend request',
        senderId: acceptorId,
        relatedId: friendshipId,
        createdAt: DateTime.now(),
      ),
    );

    await _notificationService.updateNotificationByRelatedId(
      requestedBy,
      friendshipId,
      NotificationStatus.accepted,
    );
  }

  Future<void> declineRequest(String friendshipId,
      {String? declinerUid, String? declinerNotificationId}) async {
    final friendshipDoc =
        await _db.collection('friends').doc(friendshipId).get();
    final friendshipData = friendshipDoc.data();

    await _db.collection('friends').doc(friendshipId).delete();

    if (declinerUid != null && declinerNotificationId != null) {
      await _notificationService.updateNotificationStatus(
        declinerUid,
        declinerNotificationId,
        NotificationStatus.declined,
      );
    }

    if (friendshipData != null) {
      final userIds =
          (friendshipData['userIds'] as List?)?.cast<String>() ?? [];
      final requestedBy = friendshipData['requestedBy'] as String?;

      if (requestedBy != null && userIds.length == 2) {
        await _notificationService.updateNotificationByRelatedId(
          requestedBy,
          friendshipId,
          NotificationStatus.declined,
        );
      }
    }
  }

  Future<void> cancelRequest(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).delete();
  }

  Future<void> removeFriend(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).delete();
  }

  /// Every friendship document involving [uid], accepted or not.
  ///
  /// Deliberately does **not** filter on `status` in the query. The previous
  /// version used `.where('status', isEqualTo: 'friends')`, which silently
  /// hid any friendship whose document stored a different accepted value
  /// (or none at all) — the profile header and the list both showed 0 while
  /// the user had accepted friends. Filtering in Dart against
  /// [FriendshipStatus.isAcceptedValue] keeps the behaviour without making the
  /// result depend on one exact string, and drops the composite index
  /// requirement for this query.
  Stream<List<FriendEntity>> getAllFriendshipsStream(String uid) {
    return _db
        .collection('friends')
        .where('userIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendEntity.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<FriendEntity>> getFriendsStream(String uid) {
    return getAllFriendshipsStream(uid).map(
      (all) => all.where((f) => f.status == FriendshipStatus.friends).toList(),
    );
  }

  /// One-shot read of the same query as [getFriendsStream], straight from the
  /// server rather than the local cache.
  ///
  /// `snapshots()` emits a cache-first result, which is empty on a cold start
  /// and can stay stale; this guarantees the initial count is real.
  Future<List<FriendEntity>> fetchFriends(String uid) async {
    final snap =
        await _db.collection('friends').where('userIds', arrayContains: uid).get();
    return snap.docs
        .map((doc) => FriendEntity.fromMap(doc.id, doc.data()))
        .where((f) => f.status == FriendshipStatus.friends)
        .toList();
  }

  /// Rewrites any non-canonical accepted `status` to `'friends'`.
  ///
  /// One-off repair for friendships accepted before the value was normalised.
  /// Returns the number of documents changed. Only touches documents that are
  /// already accepted and whose status is not exactly `'friends'`, so pending
  /// requests are left alone.
  Future<int> normalizeAcceptedStatuses(String uid) async {
    final snap =
        await _db.collection('friends').where('userIds', arrayContains: uid).get();

    final batch = _db.batch();
    var changed = 0;

    for (final doc in snap.docs) {
      final raw = doc.data()['status'];
      if (raw is! String || raw == 'friends') continue;
      if (!FriendshipStatus.isAcceptedValue(raw)) continue;
      batch.update(doc.reference, {'status': 'friends'});
      changed++;
    }

    if (changed > 0) await batch.commit();
    return changed;
  }

  Stream<List<FriendEntity>> getIncomingRequestsStream(String uid) {
    return _db
        .collection('friends')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendEntity.fromMap(doc.id, doc.data()))
            .where((f) => f.requestedBy != uid)
            .toList());
  }

  Stream<List<FriendEntity>> getOutgoingRequestsStream(String uid) {
    return _db
        .collection('friends')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendEntity.fromMap(doc.id, doc.data()))
            .where((f) => f.requestedBy == uid)
            .toList());
  }

  Future<List<UserEntity>> searchUsers(String query, {String? excludeUid}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final snap = await _db
        .collection('users')
        .where('username_lower', isGreaterThanOrEqualTo: q)
        .where('username_lower', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    return snap.docs
        .map((doc) => UserEntity.fromJson(doc.data()))
        .where((u) => u.userId != excludeUid)
        .toList();
  }

  Future<Map<String, String>> getPartnerStatusMap(String uid) async {
    final partners = <String, String>{};
    final streams = [
      getFriendsStream(uid),
      getIncomingRequestsStream(uid),
      getOutgoingRequestsStream(uid),
    ];
    for (final stream in streams) {
      final list = await stream.first;
      for (final f in list) {
        partners[f.otherUserId(uid)] = f.status.value;
      }
    }
    return partners;
  }
}
