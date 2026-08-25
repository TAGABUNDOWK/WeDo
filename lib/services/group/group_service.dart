import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  Future<String> createGroup({
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
    return groupRef.id;
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final batch = _db.batch();

    final msgData = <String, dynamic>{
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'text',
      'content': text,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    };

    final groupLinkMatch = RegExp(r'wedo://group/([^\s]+)').firstMatch(text);
    if (groupLinkMatch != null) {
      final inviteGroupId = groupLinkMatch.group(1)!;
      try {
        final groupDoc = await _groups.doc(inviteGroupId).get();
        if (groupDoc.exists) {
          final gData = groupDoc.data();
          msgData['groupInviteData'] = {
            'groupId': inviteGroupId,
            'groupName': gData?['name'] ?? 'Group',
            'memberCount': gData?['memberCount'] ?? 0,
            'senderId': senderId,
            'senderName': senderName,
          };
        }
      } catch (_) {}
    }

    batch.set(_messages(groupId).doc(), msgData);

    batch.update(_groups.doc(groupId), {
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendInviteMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String sessionId,
    required String topic,
    required String hostName,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'invite',
      'content': '\ud83e\udd4a $hostName started a PickFight: "$topic"',
      'activityId': sessionId,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    final previewText = '\ud83e\udd4a PickFight: $topic';
    batch.update(_groups.doc(groupId), {
      'lastMessage': previewText,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required File imageFile,
    String caption = '',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_images/$groupId/$timestamp.jpg');
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();

    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'image',
      'content': caption,
      'imageUrl': url,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': caption.isNotEmpty ? caption : '📷 Photo',
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendAudioMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_audio/$groupId/$timestamp.m4a');
    await ref.putFile(audioFile, SettableMetadata(contentType: 'audio/mp4'));
    final url = await ref.getDownloadURL();

    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'audio',
      'content': '',
      'audioUrl': url,
      'durationSeconds': durationSeconds,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': '🎤 Voice message',
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendCallMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String callType,
    required String callStatus,
    required int durationSeconds,
  }) async {
    final batch = _db.batch();

    final callText = callType == 'video' ? 'Video call' : 'Audio call';
    final statusPrefixes = ['missed', 'declined', 'cancelled'];
    final statusText = statusPrefixes.contains(callStatus)
        ? '${callStatus[0].toUpperCase()}${callStatus.substring(1)}'
        : '';
    final displayText = statusText.isNotEmpty
        ? '$statusText $callText'
        : '$callText · ${_formatDuration(durationSeconds)}';

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'call',
      'content': displayText,
      'callType': callType,
      'callStatus': callStatus,
      'durationSeconds': durationSeconds,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': displayText,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendEventMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String eventId,
    required String title,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'event',
      'content': '📅 $title',
      'refId': eventId,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': '📅 $title',
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> sendPollMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String pollId,
    required String question,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(groupId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'poll',
      'content': '📊 $question',
      'refId': pollId,
      'reactions': {},
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_groups.doc(groupId), {
      'lastMessage': '📊 $question',
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
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

  Future<void> markMessagesAsRead(String groupId, String uid) async {
    final allDocs = await _messages(groupId).get();
    final batch = _db.batch();
    for (final doc in allDocs.docs) {
      final readBy = List<String>.from(doc.data()['read_by'] ?? []);
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          'read_by': FieldValue.arrayUnion([uid]),
        });
      }
    }
    batch.update(_groups.doc(groupId), {
      'lastMessageReadBy': FieldValue.arrayUnion([uid]),
    });
    await batch.commit();
  }

  Future<List<ChatMessage>> getMessagesOnce(String groupId) async {
    final snap = await _messages(groupId)
        .orderBy('created_at', descending: false)
        .get();
    return snap.docs.map(ChatMessage.fromFirestore).toList();
  }

  Future<int> getUnreadCount(String groupId, String uid) async {
    final readSnap = await _messages(groupId)
        .where('read_by', arrayContains: uid)
        .get();
    final totalDocs = await _messages(groupId).count().get();
    final total = totalDocs.count ?? 0;
    return total - readSnap.docs.length;
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

  Future<String> uploadGroupPhoto({
    required String groupId,
    required File imageFile,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('group_photos/$groupId/$timestamp.jpg');
    await ref.putFile(imageFile);
    final url = await ref.getDownloadURL();
    await _groups.doc(groupId).update({'photoUrl': url});
    return url;
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

  Future<void> toggleMute({required String groupId, required String uid}) async {
    final doc = await _groups.doc(groupId).get();
    final mutedBy = (doc.data()?['mutedBy'] as List?)?.cast<String>() ?? [];
    if (mutedBy.contains(uid)) {
      await _groups.doc(groupId).update({
        'mutedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await _groups.doc(groupId).update({
        'mutedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }
}
