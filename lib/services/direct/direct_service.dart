import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/direct_chat.dart';
import '../../models/message.dart';
import '../../models/user_entity.dart';
import '../../utils/constants.dart';
import '../../utils/time_format.dart';

class DirectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection(AppConstants.directChatsCollection);

  String? getCurrentUid() => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection(AppConstants.directChatMessagesSubcollection);

  Future<UserEntity?> getUser(String uid) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return UserEntity.fromJson(doc.data()!);
  }

  static String chatIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  Stream<List<DirectChat>> getUserChatsStream(String uid) {
    return _chats
        .where('members', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DirectChat.fromFirestore).toList());
  }

  Future<DirectChat?> getChat(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    if (!doc.exists) return null;
    return DirectChat.fromFirestore(doc);
  }

  Future<String> getOrCreateChat({
    required String currentUid,
    required String otherUid,
  }) async {
    final chatId = chatIdFor(currentUid, otherUid);

    await _chats.doc(chatId).set({
      'members': [currentUid, otherUid],
      'last_message': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
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
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    };

    final groupLinkMatch = RegExp(r'wedo://group/([^\s]+)').firstMatch(text);
    if (groupLinkMatch != null) {
      final inviteGroupId = groupLinkMatch.group(1)!;
      try {
        final groupDoc = await _db
            .collection(AppConstants.groupsCollection)
            .doc(inviteGroupId)
            .get();
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

    batch.set(_messages(chatId).doc(), msgData);

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': text,
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File imageFile,
    String caption = '',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_images/direct/$chatId/$timestamp.jpg');
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();

    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'image',
      'content': caption,
      'imageUrl': url,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': caption.isNotEmpty ? caption : '📷 Photo',
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendAudioMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required File audioFile,
    required int durationSeconds,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance
        .ref('chat_audio/direct/$chatId/$timestamp.m4a');
    await ref.putFile(audioFile);
    final url = await ref.getDownloadURL();

    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'audio',
      'content': '',
      'audioUrl': url,
      'durationSeconds': durationSeconds,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': '🎤 Voice message',
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendCallMessage({
    required String chatId,
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
        : '$callText · ${formatSeconds(durationSeconds)}';

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'call',
      'content': displayText,
      'callType': callType,
      'callStatus': callStatus,
      'durationSeconds': durationSeconds,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': displayText,
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendEventMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String eventId,
    required String title,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'event',
      'content': '📅 $title',
      'refId': eventId,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': '📅 $title',
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendPollMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String pollId,
    required String question,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'poll',
      'content': '📊 $question',
      'refId': pollId,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': '📊 $question',
        'senderId': senderId,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageReadBy': [senderId],
    });

    await batch.commit();
  }

  Future<void> sendSystemMessage({
    required String chatId,
    required String content,
    String senderName = '',
  }) async {
    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'sender_id': 'system',
      'senderName': senderName,
      'type': 'system',
      'content': content,
      'read_by': [],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': content,
        'senderId': 'system',
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateNickname({
    required String chatId,
    required String uid,
    required String nickname,
  }) async {
    await _chats.doc(chatId).update({
      'nicknames.$uid': nickname,
    });
  }

  Future<Map<String, String>> getNicknames(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    if (!doc.exists) return {};
    final raw = doc.data()?['nicknames'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  Future<bool> isMuted(String chatId) async {
    final doc = await _chats.doc(chatId).get();
    if (!doc.exists) return false;
    final mutedBy = (doc.data()?['mutedBy'] as List?)?.cast<String>() ?? [];
    final uid = getCurrentUid();
    return uid != null && mutedBy.contains(uid);
  }

  Future<void> toggleMute({required String chatId, required String uid}) async {
    final doc = await _chats.doc(chatId).get();
    final mutedBy = (doc.data()?['mutedBy'] as List?)?.cast<String>() ?? [];
    if (mutedBy.contains(uid)) {
      await _chats.doc(chatId).update({
        'mutedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await _chats.doc(chatId).update({
        'mutedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _messages(chatId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromFirestore).toList());
  }

  Future<void> markMessagesAsRead(String chatId, String uid) async {
    final unreadDocs = await _messages(chatId)
        .where('read_by', isNotEqualTo: uid)
        .get();
    final batch = _db.batch();
    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {
        'read_by': FieldValue.arrayUnion([uid]),
      });
    }
    batch.update(_chats.doc(chatId), {
      'lastMessageReadBy': FieldValue.arrayUnion([uid]),
    });
    await batch.commit();
  }

  Future<List<ChatMessage>> getMessagesOnce(String chatId) async {
    final snap = await _messages(chatId)
        .orderBy('created_at', descending: false)
        .get();
    return snap.docs.map(ChatMessage.fromFirestore).toList();
  }

  Future<int> getUnreadCount(String chatId, String uid) async {
    final snap = await _messages(chatId)
        .where('read_by', arrayContains: uid)
        .get();
    final totalDocs = await _messages(chatId).count().get();
    final total = totalDocs.count ?? 0;
    return total - snap.docs.length;
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newContent,
  }) async {
    await _messages(chatId).doc(messageId).update({
      'content': newContent,
      'edited': true,
    });
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required String uid,
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      await _messages(chatId).doc(messageId).delete();
    } else {
      await _messages(chatId).doc(messageId).update({
        'deleted_for': FieldValue.arrayUnion([uid]),
      });
    }
  }
}
