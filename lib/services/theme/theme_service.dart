import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_theme.dart';

class ThemeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUserTheme(String uid, AppChatTheme theme) async {
    await _db.collection('users').doc(uid).update({
      'chatTheme': theme.toFirestore(),
    });
  }

  Future<AppChatTheme?> getUserTheme(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final themeData = data['chatTheme'];
    if (themeData == null || themeData is! Map<String, dynamic>) return null;
    return AppChatTheme.fromFirestore(themeData);
  }

  Stream<AppChatTheme?> getUserThemeStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final themeData = data['chatTheme'];
      if (themeData == null || themeData is! Map<String, dynamic>) return null;
      return AppChatTheme.fromFirestore(themeData);
    });
  }

  Future<void> setChatColor(String chatId, String collection, Color color) async {
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    await _db.collection(collection).doc(chatId).update({
      'themeColor': hex,
    });
  }

  Future<void> clearChatColor(String chatId, String collection) async {
    await _db.collection(collection).doc(chatId).update({
      'themeColor': FieldValue.delete(),
    });
  }

  Future<void> setChatTheme(String chatId, String collection, String themeId) async {
    await _db.collection(collection).doc(chatId).update({
      'chatThemeId': themeId,
    });
  }

  Future<String?> getChatThemeId(String chatId, String collection) async {
    final doc = await _db.collection(collection).doc(chatId).get();
    final data = doc.data();
    if (data == null) return null;
    return data['chatThemeId'] as String?;
  }

  Stream<String?> getChatThemeStream(String chatId, String collection) {
    return _db.collection(collection).doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return data['chatThemeId'] as String?;
    });
  }

  Future<void> clearChatTheme(String chatId, String collection) async {
    await _db.collection(collection).doc(chatId).update({
      'chatThemeId': FieldValue.delete(),
    });
  }
}
