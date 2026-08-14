import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_entity.dart';
import '../location/geohash.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserDocument(UserEntity user) async {
    await _db.collection('users').doc(user.userId).set(user.toJson());
  }

  Future<void> createPendingUserDocument(String userId, String email) async {
    await _db.collection('users').doc(userId).set({
      'user_id': userId,
      'email': email,
      'is_email_verified': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserEntity?> getUserDocument(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserEntity.fromJson(doc.data()!);
  }

  Future<void> updateEmailVerified(String userId) async {
    await _db.collection('users').doc(userId).update({
      'is_email_verified': true,
    });
  }

  Future<bool> isEmailVerified(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    return doc.data()?['is_email_verified'] ?? false;
  }

  Future<bool> updateLocationIfNeeded(
    String userId,
    double lat,
    double lng,
  ) async {
    final docRef = _db.collection('users').doc(userId);
    final doc = await docRef.get();
    final data = doc.data();

    final lastRaw = data?['last_location_at'];
    final last = lastRaw is String ? DateTime.tryParse(lastRaw) : null;
    final oldLat = (data?['latitude'] as num?)?.toDouble();
    final oldLng = (data?['longitude'] as num?)?.toDouble();

    final moved = oldLat == null ||
        oldLng == null ||
        Geohash.distanceMeters(oldLat, oldLng, lat, lng) > 1000;
    final stale = last == null ||
        DateTime.now().difference(last) > const Duration(minutes: 30);

    if (!moved && !stale) return false;

    await docRef.set({
      'latitude': lat,
      'longitude': lng,
      'geohash': Geohash.encode(lat, lng, 5),
      'last_location_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    return true;
  }

  Future<List<UserEntity>> findNearbyUsers(
    double lat,
    double lng, {
    double radiusKm = 25,
    String? excludeUid,
  }) async {
    final prefixes = Geohash.coveringPrefixes(lat, lng, radiusKm);
    final results = <UserEntity>{};

    for (final prefix in prefixes) {
      final snap = await _db
          .collection('users')
          .where('geohash', isGreaterThanOrEqualTo: prefix)
          .where('geohash', isLessThanOrEqualTo: '$prefix\uf8ff')
          .limit(100)
          .get();

      for (final doc in snap.docs) {
        final user = UserEntity.fromJson(doc.data());
        if (user.geohash == null ||
            user.latitude == null ||
            user.longitude == null) {
          continue;
        }
        if (user.userId == excludeUid) continue;
        results.add(user);
      }
    }

    final nearby = results.where((user) {
      return Geohash.distanceMeters(
            lat,
            lng,
            user.latitude!,
            user.longitude!,
          ) <=
          radiusKm * 1000;
    }).toList();

    nearby.sort((a, b) {
      final da = Geohash.distanceMeters(lat, lng, a.latitude!, a.longitude!);
      final db = Geohash.distanceMeters(lat, lng, b.latitude!, b.longitude!);
      return da.compareTo(db);
    });

    return nearby;
  }

  Future<void> updateFcmToken(String userId, String? token) async {
    await _db.collection('users').doc(userId).update({
      'fcm_token': token,
    });
  }
}
