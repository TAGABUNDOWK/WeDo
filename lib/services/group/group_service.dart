import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_chat.dart';
import '../../models/message.dart';
import '../../utils/constants.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection(AppConstants.groupsCollection);

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _groups.doc(groupId).collection(AppConstants.groupMessagesSubcollection);

  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection(AppConstants.groupMembersSubcollection);

  Stream<List<GroupChat>> getUserGroupsStream(String uid) {
    return _groups
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(GroupChat.fromFirestore).toList());
  }

  Future<GroupChat?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChat.fromFirestore(doc);
  }

  Stream<GroupChat?> getGroupStream(String groupId) {
    return _groups.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GroupChat.fromFirestore(doc);
    });
  }

  Future<void> createGroup({
    required String name,
    required String createdBy,
    required String displayName,
    String? photoUrl,
  }) async {
    final groupRef = _groups.doc();
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
      'lastMessageSenderId': null,
    });

    batch.set(_members(groupRef.id).doc(createdBy), {
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': createdBy,
      'displayName': displayName,
    });

    await batch.commit();
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'text',
      'content': text,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> sendSystemMessage({
    required String groupId,
    required String content,
    String senderName = '',
  }) async {
    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': 'system',
      'senderName': senderName,
      'type': 'system',
      'content': content,
      'reactions': {},
      'read_by': [],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': content,
      'lastMessageSenderId': 'system',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<ChatMessage>> getMessagesStream(String groupId) {
    return _messages(groupId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map(ChatMessage.fromFirestore).toList());
  }

  Future<List<ChatMessage>> getMessagesOnce(String groupId) async {
    final snap = await _messages(groupId)
        .orderBy('created_at', descending: false)
        .get();
    return snap.docs.map(ChatMessage.fromFirestore).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupMembersWithNames(
    String groupId,
  ) async {
    final groupDoc = await _groups.doc(groupId).get();
    if (!groupDoc.exists) return [];

    final memberIds =
        List<String>.from(groupDoc.data()?['members'] ?? []);
    final memberData = <Map<String, dynamic>>[];

    for (final uid in memberIds) {
      final memberDoc = await _members(groupId).doc(uid).get();
      final nickname = memberDoc.data()?['displayName'] as String?;

      final userDoc =
          await _db.collection(AppConstants.usersCollection).doc(uid).get();
      memberData.add({
        'uid': uid,
        'displayName':
            nickname ?? userDoc.data()?['displayName'] ?? userDoc.data()?['display_name'] ?? uid,
      });
    }
    return memberData;
  }

  Future<Map<String, String>> getMemberNicknames(String groupId) async {
    final snap = await _members(groupId).get();
    final nicknames = <String, String>{};
    for (final doc in snap.docs) {
      final name = doc.data()['displayName'] as String?;
      if (name != null) {
        nicknames[doc.id] = name;
      }
    }
    return nicknames;
  }

  Future<void> updateMemberNickname({
    required String groupId,
    required String memberUid,
    required String displayName,
  }) async {
    await _members(groupId).doc(memberUid).update({
      'displayName': displayName,
    });
  }

  Future<void> updateGroupName({
    required String groupId,
    required String name,
  }) async {
    await _groups.doc(groupId).update({'name': name});
  }

  Future<void> updateGroupPhoto({
    required String groupId,
    required String photoUrl,
  }) async {
    await _groups.doc(groupId).update({'photoUrl': photoUrl});
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
    final batch = _db.batch();

    batch.update(_groups.doc(groupId), {
      'members': FieldValue.arrayUnion([memberUid]),
      'memberCount': FieldValue.increment(1),
    });

    batch.set(_members(groupId).doc(memberUid), {
      'role': role,
      'joinedAt': FieldValue.serverTimestamp(),
      'invitedBy': invitedBy,
      'displayName': displayName,
    });

    await batch.commit();
  }

  Future<void> removeMember({
    required String groupId,
    required String memberUid,
  }) async {
    final batch = _db.batch();

    batch.update(_groups.doc(groupId), {
      'members': FieldValue.arrayRemove([memberUid]),
      'memberCount': FieldValue.increment(-1),
    });

    batch.delete(_members(groupId).doc(memberUid));

    await batch.commit();
  }

  Future<void> deleteGroup(String groupId) async {
    await _groups.doc(groupId).delete();
  }
}
