import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../../models/poll.dart';
import '../../utils/constants.dart';
import '../notification/notification_service.dart';

class PollService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> _polls(String? chatId, {String? groupId}) {
    if (groupId != null) {
      return _db
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .collection(AppConstants.pollsSubcollection);
    }
    return _db
        .collection(AppConstants.directChatsCollection)
        .doc(chatId!)
        .collection(AppConstants.pollsSubcollection);
  }

  CollectionReference<Map<String, dynamic>> _votes(
    String? chatId,
    String pollId, {
    String? groupId,
  }) {
    return _polls(chatId, groupId: groupId)
        .doc(pollId)
        .collection(AppConstants.votesSubcollection);
  }

  CollectionReference<Map<String, dynamic>> _messages(
    String? chatId, {
    String? groupId,
  }) {
    if (groupId != null) {
      return _db
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .collection(AppConstants.groupMessagesSubcollection);
    }
    return _db
        .collection(AppConstants.directChatsCollection)
        .doc(chatId!)
        .collection(AppConstants.directChatMessagesSubcollection);
  }

  DocumentReference<Map<String, dynamic>> _parentDoc(
    String? chatId, {
    String? groupId,
  }) {
    if (groupId != null) {
      return _db.collection(AppConstants.groupsCollection).doc(groupId);
    }
    return _db.collection(AppConstants.directChatsCollection).doc(chatId!);
  }

  Future<void> _sendVoteSystemMessage({
    required String pollId,
    required String uid,
    required String voterName,
    required String content,
    String? chatId,
    String? groupId,
  }) async {
    final batch = _db.batch();

    batch.set(_messages(chatId, groupId: groupId).doc(), {
      'sender_id': uid,
      'senderName': voterName,
      'type': 'system',
      'content': content,
      'reactions': {},
      'read_by': [],
      'created_at': FieldValue.serverTimestamp(),
      'createdAtLocal': DateTime.now().toIso8601String(),
      'edited': false,
    });

    batch.update(_parentDoc(chatId, groupId: groupId), {
      'lastMessage': content,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<String> createPoll({
    required String createdBy,
    required PollType type,
    required String question,
    required List<String> options,
    DateTime? closesAt,
    String? chatId,
    String? groupId,
  }) async {
    final pollRef = _polls(chatId, groupId: groupId).doc();
    final results = <String, dynamic>{'totalVoters': 0};
    for (final option in options) {
      results[option] = 0;
    }
    final pollData = ChatPoll(
      id: pollRef.id,
      createdBy: createdBy,
      type: type,
      question: question,
      options: options,
      anonymous: type == PollType.secret,
      createdAt: DateTime.now(),
      closesAt: closesAt,
      results: results,
      chatId: chatId,
      groupId: groupId,
    );
    await pollRef.set(pollData.toFirestore());
    return pollRef.id;
  }

  Stream<ChatPoll?> getPollStream(String pollId, {String? chatId, String? groupId}) {
    return _polls(chatId, groupId: groupId)
        .doc(pollId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ChatPoll.fromFirestore(doc);
    });
  }

  Future<ChatPoll?> getPoll(String pollId, {String? chatId, String? groupId}) async {
    final doc = await _polls(chatId, groupId: groupId).doc(pollId).get();
    if (!doc.exists) return null;
    return ChatPoll.fromFirestore(doc);
  }

  Future<void> votePublic({
    required String pollId,
    required String uid,
    required String option,
    String? voterName,
    String? chatId,
    String? groupId,
  }) async {
    final votesCollection = _votes(chatId, pollId, groupId: groupId);
    final pollRef = _polls(chatId, groupId: groupId).doc(pollId);
    var isNewVote = false;

    await _db.runTransaction((transaction) async {
      final voteDoc = votesCollection.doc(uid);
      final existing = await transaction.get(voteDoc);
      final oldOption = existing.data()?['option'] as String?;

      if (existing.exists && oldOption == option) return;

      transaction.set(voteDoc, {
        'option': option,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (existing.exists) {
        transaction.update(pollRef, {
          'results.$oldOption': FieldValue.increment(-1),
          'results.$option': FieldValue.increment(1),
        });
      } else {
        isNewVote = true;
        transaction.update(pollRef, {
          'results.totalVoters': FieldValue.increment(1),
          'results.$option': FieldValue.increment(1),
        });
      }
    });

    if (!isNewVote) return;

    await _notifyPollCreator(pollId, uid, false, chatId: chatId, groupId: groupId);

    if (voterName != null && voterName.isNotEmpty) {
      final displayName = voterName.length > 12 ? '${voterName.substring(0, 12)}…' : voterName;
      await _sendVoteSystemMessage(
        pollId: pollId,
        uid: uid,
        voterName: voterName,
        content: '$displayName voted on the poll',
        chatId: chatId,
        groupId: groupId,
      );
    }
  }

  Future<void> voteSecret({
    required String pollId,
    required String uid,
    required String option,
    String? voterName,
    String? chatId,
    String? groupId,
  }) async {
    final poll = await getPoll(pollId, chatId: chatId, groupId: groupId);
    if (poll == null) return;

    final voterHash = sha256.convert(utf8.encode('$uid:${poll.id}')).toString();
    final votesCollection = _votes(chatId, pollId, groupId: groupId);
    final pollRef = _polls(chatId, groupId: groupId).doc(pollId);
    var isNewVote = false;

    final legacy = await votesCollection
        .where('voterHash', isEqualTo: voterHash)
        .limit(1)
        .get();
    final legacyDoc = legacy.docs.isNotEmpty ? legacy.docs.first.reference : null;

    await _db.runTransaction((transaction) async {
      final voteDoc = votesCollection.doc('secret_$voterHash');
      final existing = await transaction.get(voteDoc);
      DocumentReference<Map<String, dynamic>> target;
      String? oldOption;

      if (existing.exists) {
        target = voteDoc;
        oldOption = existing.data()?['option'] as String?;
      } else if (legacyDoc != null) {
        target = legacyDoc;
        final legacySnapshot = await transaction.get(legacyDoc);
        oldOption = legacySnapshot.data()?['option'] as String?;
      } else {
        isNewVote = true;
        target = voteDoc;
      }

      if (!isNewVote && oldOption == option) return;

      transaction.set(target, {
        'option': option,
        'voterHash': voterHash,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (isNewVote) {
        transaction.update(pollRef, {
          'results.totalVoters': FieldValue.increment(1),
          'results.$option': FieldValue.increment(1),
        });
      } else {
        transaction.update(pollRef, {
          'results.$oldOption': FieldValue.increment(-1),
          'results.$option': FieldValue.increment(1),
        });
      }
    });

    if (!isNewVote) return;

    await _notifyPollCreator(pollId, uid, true, chatId: chatId, groupId: groupId);

    await _sendVoteSystemMessage(
      pollId: pollId,
      uid: uid,
      voterName: 'Anonymous',
      content: 'Anonymous voted on the poll',
      chatId: chatId,
      groupId: groupId,
    );
  }

  Future<void> closePoll({
    required String pollId,
    String? chatId,
    String? groupId,
  }) async {
    await _polls(chatId, groupId: groupId).doc(pollId).update({
      'closed': true,
    });
  }

  Future<void> deletePoll({
    required String pollId,
    String? chatId,
    String? groupId,
  }) async {
    await _polls(chatId, groupId: groupId).doc(pollId).delete();
  }

  Future<bool> hasVoted(String pollId, String uid, {String? chatId, String? groupId}) async {
    final poll = await getPoll(pollId, chatId: chatId, groupId: groupId);
    if (poll == null) return false;

    if (poll.type == PollType.secret) {
      final voterHash = sha256.convert(utf8.encode('$uid:$pollId')).toString();
      final snapshot = await _votes(chatId, pollId, groupId: groupId)
          .where('voterHash', isEqualTo: voterHash)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } else {
      final voteDoc = await _votes(chatId, pollId, groupId: groupId).doc(uid).get();
      return voteDoc.exists;
    }
  }

  Future<String?> getMyVoteOption(String pollId, String uid, {String? chatId, String? groupId}) async {
    final poll = await getPoll(pollId, chatId: chatId, groupId: groupId);
    if (poll == null) return null;

    if (poll.type == PollType.secret) {
      final voterHash = sha256.convert(utf8.encode('$uid:$pollId')).toString();
      final snapshot = await _votes(chatId, pollId, groupId: groupId)
          .where('voterHash', isEqualTo: voterHash)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data()['option'] as String?;
    } else {
      final voteDoc = await _votes(chatId, pollId, groupId: groupId).doc(uid).get();
      if (!voteDoc.exists) return null;
      return voteDoc.data()?['option'] as String?;
    }
  }

  Future<Map<String, List<String>>> getVotersByOption(
    String pollId, {
    String? chatId,
    String? groupId,
  }) async {
    final snapshot = await _votes(chatId, pollId, groupId: groupId).get();
    final Map<String, List<String>> votersByOption = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final option = data['option'] as String? ?? '';
      final uid = data['uid'] as String?;
      if (uid != null && option.isNotEmpty) {
        votersByOption.putIfAbsent(option, () => []).add(uid);
      }
    }
    return votersByOption;
  }

  Future<void> _notifyPollCreator(
    String pollId,
    String voterId,
    bool isSecret, {
    String? chatId,
    String? groupId,
  }) async {
    try {
      final poll = await getPoll(pollId, chatId: chatId, groupId: groupId);
      if (poll == null || poll.createdBy == voterId) return;

      final voterDoc = await _db
          .collection(AppConstants.usersCollection)
          .doc(voterId)
          .get();
      final voterName = voterDoc.data()?['display_name'] as String? ?? 'Someone';

      await _notificationService.createPollVoteNotification(
        creatorId: poll.createdBy,
        voterId: voterId,
        voterName: voterName,
        pollId: pollId,
        question: poll.question,
        isSecret: isSecret,
      );
    } catch (_) {}
  }
}
