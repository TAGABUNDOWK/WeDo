import 'package:cloud_firestore/cloud_firestore.dart';

/// The three RSVP states an event member can pick.
///
/// [storage] keeps the legacy Firestore values ('yes' / 'no') so documents
/// written by older app versions continue to parse, and adds 'maybe' as the
/// third state.
enum EventResponse {
  interested('yes'),
  notSure('maybe'),
  notInterested('no');

  const EventResponse(this.storage);

  final String storage;

  static EventResponse? parse(String? raw) {
    for (final r in EventResponse.values) {
      if (r.storage == raw) return r;
    }
    return null;
  }

  /// Human-readable label shared by every screen that renders the options.
  String get label {
    switch (this) {
      case EventResponse.interested:
        return 'Interested';
      case EventResponse.notSure:
        return 'Not Sure';
      case EventResponse.notInterested:
        return 'Not Interested';
    }
  }
}

class ChatEvent {
  final String id;
  final String createdBy;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? endDate;
  final String? location;
  final String? dressCode;
  final String? imageUrl;
  final Map<String, String> rsvps;
  final bool showRsvpMessages;
  final String? chatId;
  final String? groupId;
  final DateTime createdAt;

  const ChatEvent({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.date,
    this.endDate,
    this.location,
    this.dressCode,
    this.imageUrl,
    this.rsvps = const {},
    this.showRsvpMessages = false,
    this.chatId,
    this.groupId,
    required this.createdAt,
  });

  bool get isStarted => DateTime.now().isAfter(date);
  bool get isEnded => endDate != null && DateTime.now().isAfter(endDate!);

  factory ChatEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatEvent(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      date: _parseTimestamp(data['date']) ?? DateTime.now(),
      endDate: _parseTimestamp(data['endDate']),
      location: data['location'] as String?,
      dressCode: data['dressCode'] as String?,
      imageUrl: data['imageUrl'] as String?,
      rsvps: Map<String, String>.from(data['rsvps'] as Map? ?? {}),
      showRsvpMessages: data['showRsvpMessages'] as bool? ?? false,
      chatId: data['chatId'] as String?,
      groupId: data['groupId'] as String?,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdBy': createdBy,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'location': location,
      'dressCode': dressCode,
      'imageUrl': imageUrl,
      'rsvps': rsvps,
      'showRsvpMessages': showRsvpMessages,
      'chatId': chatId,
      'groupId': groupId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int countFor(EventResponse response) =>
      rsvps.values.where((v) => v == response.storage).length;

  int get interestedCount => countFor(EventResponse.interested);
  int get notSureCount => countFor(EventResponse.notSure);
  int get notInterestedCount => countFor(EventResponse.notInterested);
  int get totalResponses => rsvps.length;

  List<String> votersFor(EventResponse response) => rsvps.entries
      .where((e) => e.value == response.storage)
      .map((e) => e.key)
      .toList();

  String? myRsvp(String uid) => rsvps[uid];

  EventResponse? myResponse(String uid) => EventResponse.parse(rsvps[uid]);

  /// Denominator for proportional RSVP fills: every group member for group
  /// events (pass [groupMemberCount] from the group document), 2 for direct
  /// chats, with a safe fallback to the responses received so far.
  int participantCount({int? groupMemberCount}) {
    if (groupId != null) {
      if (groupMemberCount != null && groupMemberCount > 0) {
        return groupMemberCount;
      }
      return totalResponses > 0 ? totalResponses : 1;
    }
    return 2;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return dt.isUtc ? dt.toLocal() : dt;
    }
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    if (value is String) {
      final dt = DateTime.parse(value);
      return dt.isUtc ? dt.toLocal() : dt;
    }
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
