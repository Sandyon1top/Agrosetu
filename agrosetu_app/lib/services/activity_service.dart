import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityService {
  static const String _key = 'agro_activities_v1';

  static Future<List<Map<String, dynamic>>> getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final List decoded = json.decode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentActivities(int limit) async {
    final all = await getAllActivities();
    all.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    return all.take(limit).toList();
  }

  static Future<void> addActivity(String type, String title, {Map<String, dynamic>? meta}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAllActivities();
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'title': title,
      'timestamp': DateTime.now().toIso8601String(),
      'meta': meta ?? {},
    };
    list.add(entry);
    await prefs.setString(_key, json.encode(list));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
