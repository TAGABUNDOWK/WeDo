import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_entity.dart';
import '../../utils/constants.dart';

class UserCache {
  static final UserCache _instance = UserCache._();
  factory UserCache() => _instance;
  UserCache._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, UserEntity?> _cache = {};

  Future<UserEntity?> getUser(String uid) async {
    if (_cache.containsKey(uid)) return _cache[uid];
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    final user = doc.exists ? UserEntity.fromJson(doc.data()!) : null;
    _cache[uid] = user;
    return user;
  }

  UserEntity? getCachedUser(String uid) => _cache[uid];

  void putUser(String uid, UserEntity? user) {
    _cache[uid] = user;
  }

  void removeUser(String uid) {
    _cache.remove(uid);
  }

  void clear() {
    _cache.clear();
  }
}
