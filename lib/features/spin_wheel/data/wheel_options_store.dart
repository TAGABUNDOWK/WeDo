import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wheel_option.dart';

class WheelOptionsStore {
  static const _key = 'wheel_options';

  Future<List<WheelOption>?> loadOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => WheelOption.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveOptions(List<WheelOption> options) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      options.map((o) => o.toMap()).toList(),
    );
    await prefs.setString(_key, encoded);
  }
}
