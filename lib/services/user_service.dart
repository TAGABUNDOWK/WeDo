import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_entity.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserDocument(UserEntity user) async {
    await _db.collection('users').doc(user.userId).set(user.toJson());
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
}
