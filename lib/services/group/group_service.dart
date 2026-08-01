import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserGroupsStream(String uid) {
    return _db
        .collection(AppConstants.groupsCollection)
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getGroupDoc(String groupId) {
    return _db.collection(AppConstants.groupsCollection).doc(groupId).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) {
    return _db.collection(AppConstants.usersCollection).doc(uid).get();
  }

  Future<void> createGroup({
    required String name,
    required String createdBy,
    required String displayName,
    String? photoUrl,
  }) async {
    final groupRef = _db.collection(AppConstants.groupsCollection).doc();

    final batch = _db.batch();

    batch.set(groupRef, {
      'name': name,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': [createdBy],
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
    });

    batch.set(
      groupRef.collection(AppConstants.groupMembersSubcollection).doc(createdBy),
      {
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': createdBy,
        'displayName': displayName,
      },
    );

    await batch.commit();
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await _db
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .add({
      'senderId': senderId,
      'senderName': senderName,
      'type': 'text',
      'content': text,
      'reactions': {},
      'readBy': [senderId],
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    await _db.collection(AppConstants.groupsCollection).doc(groupId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(String groupId) {
    return _db
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getMessagesOnce(String groupId) {
    return _db
        .collection(AppConstants.groupsCollection)
        .doc(groupId)
        .collection(AppConstants.groupMessagesSubcollection)
        .orderBy('createdAt', descending: false)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> searchMessages({
    required String groupId,
    String? senderId,
    DateTime? startDate,
    DateTime? endDate,
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

    return query.orderBy('createdAt', descending: true).limit(limit).get();
  }

  Future<List<Map<String, dynamic>>> getGroupMembersWithNames(
    String groupId,
  ) async {
    final groupDoc = await getGroupDoc(groupId);
    if (!groupDoc.exists) return [];

    final memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);

    final memberData = <Map<String, dynamic>>[];
    for (final uid in memberIds) {
      final userDoc = await getUserDoc(uid);
      if (userDoc.exists) {
        memberData.add({
          'uid': uid,
          'displayName': userDoc.data()?['displayName'] ?? uid,
        });
      } else {
        memberData.add({'uid': uid, 'displayName': uid});
      }
    }
    return memberData;
  }

  Future<({String uid, String name})?> findUserByEmail(String email) async {
    final userQuery = await _db
        .collection(AppConstants.usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) return null;
    final doc = userQuery.docs.first;
    return (
      uid: doc.id,
      name: doc.data()['displayName'] as String? ?? 'Unknown',
    );
  }

  Future<void> addMember({
    required String groupId,
    required String memberUid,
    required String displayName,
    required String invitedBy,
    String role = 'member',
  }) async {
    final groupRef = _db.collection(AppConstants.groupsCollection).doc(groupId);

    final batch = _db.batch();

    batch.update(groupRef, {
      'members': FieldValue.arrayUnion([memberUid]),
      'memberCount': FieldValue.increment(1),
    });

    batch.set(
      groupRef.collection(AppConstants.groupMembersSubcollection).doc(memberUid),
      {
        'role': role,
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': invitedBy,
        'displayName': displayName,
      },
    );

    await batch.commit();
  }

  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    final groupRef = _db.collection(AppConstants.groupsCollection).doc(groupId);

    final batch = _db.batch();

    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([memberUid]),
      'memberCount': FieldValue.increment(-1),
    });

    batch.delete(
      groupRef.collection(AppConstants.groupMembersSubcollection).doc(memberUid),
    );

    await batch.commit();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection(AppConstants.groupsCollection).doc(groupId).delete();
  }
}
