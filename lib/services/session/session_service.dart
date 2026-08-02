import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/topic_entity.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<TopicEntity>> getTopics() async {
    final snap = await _db.collection('topics').get();
    return snap.docs
        .map((doc) => TopicEntity.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<CardEntity>> getCards(String topicId) async {
    final snap = await _db
        .collection('topics')
        .doc(topicId)
        .collection('cards')
        .get();
    return snap.docs
        .map((doc) => CardEntity.fromMap(doc.id, topicId, doc.data()))
        .toList();
  }

  List<CardEntity> pickRandomCards(List<CardEntity> cards, {int count = 10}) {
    final shuffled = List<CardEntity>.from(cards)..shuffle(Random());
    return shuffled.take(count).toList();
  }
}
