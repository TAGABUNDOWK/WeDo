class UserEntity {
  final String userId;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final String authProvider;
  final bool isPremium;
  final DateTime createdAt;
  final bool isGuest;
  final DateTime lastActiveAt;

  UserEntity({
    required this.userId,
    required this.displayName,
    this.email,
    this.photoUrl,
    required this.authProvider,
    required this.isPremium,
    required this.createdAt,
    required this.isGuest,
    required this.lastActiveAt,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      authProvider: json['auth_provider'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: _parseTimestamp(json['created_at']),
      isGuest: json['is_guest'] as bool? ?? false,
      lastActiveAt: _parseTimestamp(json['last_active_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
      'auth_provider': authProvider,
      'is_premium': isPremium,
      'created_at': createdAt.toIso8601String(),
      'is_guest': isGuest,
      'last_active_at': lastActiveAt.toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw ArgumentError('Unsupported timestamp format: $value');
  }

  UserEntity copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? photoUrl,
    String? authProvider,
    bool? isPremium,
    DateTime? createdAt,
    bool? isGuest,
    DateTime? lastActiveAt,
  }) {
    return UserEntity(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      authProvider: authProvider ?? this.authProvider,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      isGuest: isGuest ?? this.isGuest,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  @override
  String toString() {
    return 'UserEntity(userId: $userId, displayName: $displayName, '
        'email: $email, authProvider: $authProvider, '
        'isPremium: $isPremium, isGuest: $isGuest, '
        'createdAt: $createdAt, lastActiveAt: $lastActiveAt)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}
