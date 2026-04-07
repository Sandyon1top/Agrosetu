import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // ADDED
import 'api_service.dart'; // ADDED
import 'user_service.dart'; // ADDED

class NotificationService {
  static const String _notificationsKey = 'notifications_list';

  // ADDED: Backend URL helper (Adjust port if necessary)
  static const String baseUrl = 'http://127.0.0.1:5001/api';

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
    // ADDED: Sync with backend before returning the list
    await syncNotificationsWithBackend();

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

  // ADDED: New method to fetch from Node.js and save to Local Storage
  static Future<void> syncNotificationsWithBackend() async {
    try {
      final user = await UserService.getUser();
      if (user == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/notifications/${user['id']}'),
        headers: ApiService.getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List serverNotifs = data['notifications'] ?? [];
        
        // Merge server notifications into local SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final localJson = prefs.getString(_notificationsKey);
        List<dynamic> localList = localJson != null ? jsonDecode(localJson) : [];

        // Simple merge: Add server notifs if ID doesn't exist locally
        for (var sn in serverNotifs) {
          bool exists = localList.any((ln) => ln['id'] == sn['_id'] || ln['id'] == sn['id']);
          if (!exists) {
            localList.insert(0, {
              'id': sn['_id'] ?? sn['id'],
              'title': sn['type'] == 'like' ? 'New Like' : 'New Comment',
              'body': sn['message'],
              'type': sn['type'],
              'read': sn['isRead'] ?? false,
              'timestamp': sn['createdAt'] ?? DateTime.now().toIso8601String(),
            });
          }
        }
        await prefs.setString(_notificationsKey, jsonEncode(localList));
      }
    } catch (e) {
      print('Sync Error: $e');
      // If server is down, app continues using local cached data (Offline Mode)
    }
  }

  static Future<int> getUnreadCount() async {
    final notifs = await getNotifications();
    return notifs.where((n) => n['read'] != true).length;
  }

  static Future<void> markAsRead(String notificationId) async {
    // ADDED: Notify backend that it's read
    try {
      final user = await UserService.getUser();
      if (user != null) {
        await http.post(
          Uri.parse('$baseUrl/notifications/read'),
          headers: ApiService.getHeaders(),
          body: jsonEncode({'userId': user['id']}),
        );
      }
    } catch (e) {
      print('Mark as read backend error: $e');
    }

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