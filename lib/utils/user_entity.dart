class UserEntity {
  final String userId;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  UserEntity({
    required this.userId,
    required this.displayName,
    this.email,
    this.photoUrl,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: _parseTimestamp(json['createdAt']),
      lastActiveAt: _parseTimestamp(json['lastActiveAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw ArgumentError('Unsupported timestamp format: $value');
  }

  UserEntity copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserEntity(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  @override
  String toString() {
    return 'UserEntity(userId: $userId, displayName: $displayName, email: $email)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}
