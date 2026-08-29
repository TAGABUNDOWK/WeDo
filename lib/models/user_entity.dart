import 'package:cloud_firestore/cloud_firestore.dart';

class UserEntity {
  final String userId;
  final String displayName;
  final String username;
  final String usernameLower;
  final String? email;
  final String? photoUrl;
  final String? avatarAsset;
  final String? frameAsset;
  final String authProvider;
  final bool isPremium;
  final DateTime createdAt;
  final bool isGuest;
  final DateTime lastActiveAt;
  final bool isEmailVerified;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final DateTime? lastLocationAt;

  UserEntity({
    required this.userId,
    required this.displayName,
    this.username = '',
    this.usernameLower = '',
    this.email,
    this.photoUrl,
    this.avatarAsset,
    this.frameAsset,
    required this.authProvider,
    required this.isPremium,
    required this.createdAt,
    required this.isGuest,
    required this.lastActiveAt,
    this.isEmailVerified = false,
    this.latitude,
    this.longitude,
    this.geohash,
    this.lastLocationAt,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      username: json['username'] as String? ?? '',
      usernameLower: json['username_lower'] as String? ?? '',
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      avatarAsset: json['avatar_asset'] as String?,
      frameAsset: json['frame_asset'] as String?,
      authProvider: json['auth_provider'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: _parseTimestamp(json['created_at']),
      isGuest: json['is_guest'] as bool? ?? false,
      lastActiveAt: _parseTimestamp(json['last_active_at']),
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      lastLocationAt: _parseOptionalTimestamp(json['last_location_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'username': username,
      'username_lower': usernameLower,
      'email': email,
      'photo_url': photoUrl,
      'avatar_asset': avatarAsset,
      'frame_asset': frameAsset,
      'auth_provider': authProvider,
      'is_premium': isPremium,
      'created_at': createdAt.toIso8601String(),
      'is_guest': isGuest,
      'last_active_at': lastActiveAt.toIso8601String(),
      'is_email_verified': isEmailVerified,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'last_location_at': lastLocationAt?.toIso8601String(),
    };
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    throw ArgumentError('Unsupported timestamp format: $value');
  }

  static DateTime? _parseOptionalTimestamp(dynamic value) {
    if (value == null) return null;
    return _parseTimestamp(value);
  }

  UserEntity copyWith({
    String? userId,
    String? displayName,
    String? username,
    String? usernameLower,
    String? email,
    String? photoUrl,
    String? avatarAsset,
    String? frameAsset,
    String? authProvider,
    bool? isPremium,
    DateTime? createdAt,
    bool? isGuest,
    DateTime? lastActiveAt,
    bool? isEmailVerified,
    double? latitude,
    double? longitude,
    String? geohash,
    DateTime? lastLocationAt,
  }) {
    return UserEntity(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      usernameLower: usernameLower ?? this.usernameLower,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      frameAsset: frameAsset ?? this.frameAsset,
      authProvider: authProvider ?? this.authProvider,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      isGuest: isGuest ?? this.isGuest,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
    );
  }

  @override
  String toString() {
    return 'UserEntity(userId: $userId, displayName: $displayName, '
        'username: $username, email: $email, authProvider: $authProvider, '
        'isPremium: $isPremium, isGuest: $isGuest, '
        'isEmailVerified: $isEmailVerified, '
        'createdAt: $createdAt, lastActiveAt: $lastActiveAt)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}
