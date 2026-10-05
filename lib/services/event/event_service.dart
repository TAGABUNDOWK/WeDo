import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/event.dart';
import '../../utils/constants.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
    String? imageUrl,
    bool showRsvpMessages = false,
    String? chatId,
    String? groupId,
    String? source,
    String? cardType,
    double? latitude,
    double? longitude,
    String? address,
    String? placeId,
    String? tag,
    String? rating,
    String? distanceSnapshot,
    String? sessionId,
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
      imageUrl: imageUrl,
      showRsvpMessages: showRsvpMessages,
      chatId: chatId,
      groupId: groupId,
      createdAt: DateTime.now(),
      source: source,
      cardType: cardType,
      latitude: latitude,
      longitude: longitude,
      address: address,
      placeId: placeId,
      tag: tag,
      rating: rating,
      distanceSnapshot: distanceSnapshot,
      sessionId: sessionId,
    );
    await eventRef.set(eventData.toFirestore());
    return eventRef.id;
  }

  /// Uploads an optional event cover photo to Firebase Storage and returns
  /// the download URL. Mirrors [uploadGroupPhoto] in GroupService.
  Future<String> uploadEventImage({
    required String? chatId,
    required String? groupId,
    required File file,
  }) async {
    final scope = groupId ?? chatId;
    if (scope == null) {
      throw Exception('Event image requires a chatId or groupId');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('event_photos/$scope/$timestamp.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
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

  /// Removes the user's RSVP (used when they tap their own selection again).
  Future<void> clearRsvp({
    required String eventId,
    required String uid,
    String? chatId,
    String? groupId,
  }) async {
    await _events(chatId, groupId: groupId).doc(eventId).update({
      'rsvps.$uid': FieldValue.delete(),
    });
  }

  /// Single write path for three-option voting, shared by the chat card and
  /// the detail screen: clears the RSVP when [uid] taps their current
  /// selection again (toggle off), otherwise writes [response]. No-ops while
  /// RSVPs are locked (event has ended).
  Future<void> submitResponse({
    required ChatEvent event,
    required String uid,
    required EventResponse response,
  }) async {
    if (uid.isEmpty || event.isEnded) return;
    if (event.myResponse(uid) == response) {
      await clearRsvp(
        eventId: event.id,
        uid: uid,
        chatId: event.chatId,
        groupId: event.groupId,
      );
    } else {
      await rsvpEvent(
        eventId: event.id,
        uid: uid,
        response: response.storage,
        chatId: event.chatId,
        groupId: event.groupId,
      );
    }
  }

  Future<void> deleteEvent({
    required String eventId,
    String? chatId,
    String? groupId,
  }) async {
    await _events(chatId, groupId: groupId).doc(eventId).delete();
  }
}
