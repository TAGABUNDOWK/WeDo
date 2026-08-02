import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/friend_entity.dart';
import '../../models/user_entity.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  }

  Future<void> acceptRequest(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).update({
      'status': 'friends',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineRequest(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).delete();
  }

  Future<void> cancelRequest(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).delete();
  }

  Future<void> removeFriend(String friendshipId) async {
    await _db.collection('friends').doc(friendshipId).delete();
  }

  Stream<List<FriendEntity>> getFriendsStream(String uid) {
    return _db
        .collection('friends')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: 'friends')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendEntity.fromMap(doc.id, doc.data()))
            .toList());
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
