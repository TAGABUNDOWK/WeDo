import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxSizeBytes = 5 * 1024 * 1024;

  /// Uploads avatar to Firebase Storage and persists downloadUrl to Firestore.
  /// File survives logout because Storage + Firestore are independent of Auth session;
  /// only auth deletion triggers cleanup (handled in Cloud Function).
  /// Circle clipping is UI-only (ClipOval) — image stored as original jpg.
  Future<String> uploadAvatar({required String uid, required XFile file}) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != uid) {
      throw Exception('Not authenticated or uid mismatch');
    }
    final f = File(file.path);
    final len = await f.length();
    if (len > maxSizeBytes) {
      throw Exception('Image too large (max 5MB)');
    }

    final ref = _storage.ref('profile_photos/$uid.jpg');
    final metadata = SettableMetadata(
      contentType: file.mimeType ?? 'image/jpeg',
      cacheControl: 'public,max-age=31536000',
      customMetadata: {'uploadedBy': uid},
    );

    await ref.putFile(f, metadata);
    final url = await ref.getDownloadURL();

    await _db.collection('users').doc(uid).update({
      'photo_url': url,
      'photo_updated_at': FieldValue.serverTimestamp(),
      'moderation_status': 'pending',
    });

    return url;
  }

  Future<void> removeAvatar(String uid) async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null || authUid != uid) throw Exception('Not authenticated');
    try {
      await _storage.ref('profile_photos/$uid.jpg').delete();
    } catch (_) {}
    await _db.collection('users').doc(uid).update({
      'photo_url': FieldValue.delete(),
      'moderation_status': FieldValue.delete(),
      'photo_updated_at': FieldValue.serverTimestamp(),
    });
  }
}
