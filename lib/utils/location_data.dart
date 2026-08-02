import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/admin_division.dart';

class LocationData {
  static Map<String, List<AdminDivision>>? _cache;

  static Future<List<String>> getProvinces() async {
    final data = await _load();
    final provinces = data.keys.toList()..sort();
    return provinces;
  }

  static Future<List<AdminDivision>> getCities(String provinceName) async {
    final data = await _load();
    return data[provinceName] ?? [];
  }

  static Future<Map<String, List<AdminDivision>>> _load() async {
    if (_cache != null) return _cache!;

    try {
      final json = await rootBundle.loadString(
        'assets/data/philippines_provinces_cities.json',
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final provinces = decoded['provinces'] as List? ?? [];

      final result = <String, List<AdminDivision>>{};
      for (final province in provinces) {
        final p = province as Map<String, dynamic>;
        final name = p['name'] as String? ?? '';
        final cities = (p['cities'] as List? ?? [])
            .map((c) => AdminDivision.fromJson(c as Map<String, dynamic>))
            .toList();
        result[name] = cities;
      }

      _cache = result;
      return _cache!;
    } catch (e) {
      debugPrint('[LocationData] Error loading JSON: $e');
      return {};
    }
  }
}
