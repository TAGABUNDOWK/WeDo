import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event.dart';
import '../../utils/constants.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _events(String? chatId, {String? groupId}) {
    if (groupId != null) {
      return _db
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .collection(AppConstants.eventsSubcollection);
    }
    return _db
        .collection(AppConstants.directChatsCollection)
        .doc(chatId!)
        .collection(AppConstants.eventsSubcollection);
  }

  Future<String> createEvent({
    required String createdBy,
    required String title,
    required String description,
    required DateTime date,
    DateTime? endDate,
    String? location,
    String? dressCode,
    bool showRsvpMessages = false,
    String? chatId,
    String? groupId,
  }) async {
    final eventRef = _events(chatId, groupId: groupId).doc();
    final eventData = ChatEvent(
      id: eventRef.id,
      createdBy: createdBy,
      title: title,
      description: description,
      date: date,
      endDate: endDate,
      location: location,
      dressCode: dressCode,
      showRsvpMessages: showRsvpMessages,
      chatId: chatId,
      groupId: groupId,
      createdAt: DateTime.now(),
    );
    await eventRef.set(eventData.toFirestore());
    return eventRef.id;
  }

  Stream<ChatEvent?> getEventStream(String eventId, {String? chatId, String? groupId}) {
    return _events(chatId, groupId: groupId)
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ChatEvent.fromFirestore(doc);
    });
  }

  Future<ChatEvent?> getEvent(String eventId, {String? chatId, String? groupId}) async {
    final doc = await _events(chatId, groupId: groupId).doc(eventId).get();
    if (!doc.exists) return null;
    return ChatEvent.fromFirestore(doc);
  }

  Future<void> rsvpEvent({
    required String eventId,
    required String uid,
    required String response,
    String? chatId,
    String? groupId,
  }) async {
    await _events(chatId, groupId: groupId).doc(eventId).update({
      'rsvps.$uid': response,
    });
  }

  Future<void> deleteEvent({
    required String eventId,
    String? chatId,
    String? groupId,
  }) async {
    await _events(chatId, groupId: groupId).doc(eventId).delete();
  }
}
