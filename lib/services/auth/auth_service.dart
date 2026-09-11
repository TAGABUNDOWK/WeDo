import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Reauthenticate the current user with email/password credentials.
  /// Required before sensitive operations (email change, password change, account deletion).
  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Send a verification email to the new address before changing.
  /// Firebase Auth requires verification before email can be updated.
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  /// Update the current user's password.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    await user.updatePassword(newPassword);
  }

  /// Delete the current user from Firebase Auth.
  /// This triggers the Cloud Function `cleanupUserData` for Firestore/Storage cleanup.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    await user.delete();
  }
}
