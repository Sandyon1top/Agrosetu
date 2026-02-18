import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static const String _notificationsKey = 'notifications_list';

  static Future<void> addNotification(Map<String, dynamic> notification) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    
    final newNotif = {
      ...notification,
      'timestamp': DateTime.now().toIso8601String(),
      'id': '${DateTime.now().millisecondsSinceEpoch}',
    };
    
    list.insert(0, newNotif);
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notifJson = prefs.getString(_notificationsKey);
    if (notifJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(notifJson);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<int> getUnreadCount() async {
    final notifs = await getNotifications();
    return notifs.where((n) => n['read'] != true).length;
  }

  static Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getNotifications();
    
    for (var notif in list) {
      if (notif['id'] == notificationId) {
        notif['read'] = true;
      }
    }
    
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }
}
