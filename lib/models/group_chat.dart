import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChat {
  final String id;
  final String name;
  final String? photoUrl;
  final String createdBy;
  final List<String> members;
  final int memberCount;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final List<String> lastMessageReadBy;
  final DateTime createdAt;

  const GroupChat({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.createdBy,
    required this.members,
    required this.memberCount,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.lastMessageReadBy = const [],
    required this.createdAt,
  });

  factory GroupChat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupChat(
      id: doc.id,
      name: data['name'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      members: (data['members'] as List?)?.cast<String>() ?? const [],
      memberCount: data['memberCount'] as int? ?? 0,
      lastMessage: data['lastMessage'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageAt: _parseTimestamp(data['lastMessageAt']),
      lastMessageReadBy: (data['lastMessageReadBy'] as List?)?.cast<String>() ?? const [],
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': members,
      'memberCount': memberCount,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : FieldValue.serverTimestamp(),
      'lastMessageReadBy': lastMessageReadBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool isMember(String uid) => members.contains(uid);
  bool isAdmin(String uid) => createdBy == uid;

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupChat && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
