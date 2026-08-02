import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/direct_chat.dart';
import '../../models/message.dart';
import '../../models/user_entity.dart';
import '../../utils/constants.dart';

class DirectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection(AppConstants.directChatsCollection);

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

    batch.set(_messages(chatId).doc(), {
      'sender_id': senderId,
      'senderName': senderName,
      'type': 'text',
      'content': text,
      'read_by': [senderId],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_chats.doc(chatId), {
      'last_message': {
        'text': text,
        'senderId': senderId,
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

  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    return _messages(chatId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromFirestore).toList());
  }

  Future<List<ChatMessage>> getMessagesOnce(String chatId) async {
    final snap = await _messages(chatId)
        .orderBy('created_at', descending: false)
        .get();
    return snap.docs.map(ChatMessage.fromFirestore).toList();
  }
}
