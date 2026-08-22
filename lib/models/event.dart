import 'package:cloud_firestore/cloud_firestore.dart';

class ChatEvent {
  final String id;
  final String createdBy;
  final String title;
  final String description;
  final DateTime date;
  final DateTime? endDate;
  final String? location;
  final String? dressCode;
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
      'rsvps': rsvps,
      'showRsvpMessages': showRsvpMessages,
      'chatId': chatId,
      'groupId': groupId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int get yesCount => rsvps.values.where((v) => v == 'yes').length;
  int get noCount => rsvps.values.where((v) => v == 'no').length;
  int get maybeCount => rsvps.values.where((v) => v == 'maybe').length;
  int get totalResponses => rsvps.length;

  String? myRsvp(String uid) => rsvps[uid];

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
