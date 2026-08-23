import 'package:cloud_firestore/cloud_firestore.dart';

enum PollType {
  public,
  secret;

  String get value {
    switch (this) {
      case PollType.public:
        return 'public';
      case PollType.secret:
        return 'secret';
    }
  }
}

class ChatPoll {
  final String id;
  final String createdBy;
  final PollType type;
  final String question;
  final List<String> options;
  final bool anonymous;
  final DateTime createdAt;
  final DateTime? closesAt;
  final Map<String, dynamic> results;
  final bool closed;
  final String? chatId;
  final String? groupId;

  const ChatPoll({
    required this.id,
    required this.createdBy,
    required this.type,
    required this.question,
    required this.options,
    required this.anonymous,
    required this.createdAt,
    this.closesAt,
    this.results = const {},
    this.closed = false,
    this.chatId,
    this.groupId,
  });

  factory ChatPoll.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final typeStr = data['type'] as String? ?? 'public';
    return ChatPoll(
      id: doc.id,
      createdBy: data['createdBy'] as String? ?? '',
      type: typeStr == 'secret' ? PollType.secret : PollType.public,
      question: data['question'] as String? ?? '',
      options: (data['options'] as List?)?.cast<String>() ?? const [],
      anonymous: data['anonymous'] as bool? ?? false,
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      closesAt: _parseTimestamp(data['closesAt']),
      results: Map<String, dynamic>.from(data['results'] as Map? ?? {}),
      closed: data['closed'] as bool? ?? false,
      chatId: data['chatId'] as String?,
      groupId: data['groupId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'createdBy': createdBy,
      'type': type.value,
      'question': question,
      'options': options,
      'anonymous': anonymous,
      'createdAt': Timestamp.fromDate(createdAt),
      'closesAt': closesAt != null ? Timestamp.fromDate(closesAt!) : null,
      'results': results,
      'closed': closed,
      'chatId': chatId,
      'groupId': groupId,
    };
  }

  int get totalVotes => results['totalVoters'] as int? ?? 0;

  int votesForOption(String option) => results[option] as int? ?? 0;

  bool get isExpired =>
      closesAt != null && DateTime.now().isAfter(closesAt!);

  bool get isClosed => closed || isExpired;

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatPoll && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
