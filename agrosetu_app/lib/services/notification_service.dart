import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // ADDED
import 'api_service.dart'; // ADDED
import 'user_service.dart'; // ADDED

class NotificationService {
  static const String _notificationsKey = 'notifications_list';

  // ADDED: Backend URL helper (Adjust port if necessary)
  static const String baseUrl = 'http://192.168.101.3:5001/api';

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

        for (var sn in serverNotifs) {
          final String sId = (sn['_id'] ?? sn['id']).toString();
          
          // Find index of existing notification
          int index = localList.indexWhere((ln) => ln['id'].toString() == sId);
          
          if (index == -1) {
            // New notification - Insert at start
            localList.insert(0, {
              'id': sId,
              'title': sn['type'] == 'like' ? 'New Like' : 'New Comment',
              'body': sn['message'],
              'type': sn['type'],
              'read': sn['isRead'] ?? false,
              'timestamp': sn['createdAt'] ?? DateTime.now().toIso8601String(),
              'postId': sn['postId']?.toString(), // ENSURE STRING
              'senderName': sn['senderName']?.toString(), // ENSURE STRING
              'postTitle': sn['postTitle']?.toString(), // ENSURE STRING
            });
          } else {
            // Update existing notification with missing fields
            var ln = localList[index];
            bool modified = false;
            
            if (ln['postId'] == null && sn['postId'] != null) {
              ln['postId'] = sn['postId'].toString(); // ENSURE STRING
              modified = true;
            }
            if (ln['senderName'] == null && sn['senderName'] != null) {
              ln['senderName'] = sn['senderName'].toString(); // ENSURE STRING
              modified = true;
            }
            if (ln['postTitle'] == null && sn['postTitle'] != null) {
              ln['postTitle'] = sn['postTitle'].toString(); // ENSURE STRING
              modified = true;
            }
            
            if (modified) localList[index] = ln;
          }
        }
        debugPrint('[NotificationService] Synced ${localList.length} notifications. Latest IDs: ${localList.take(3).map((n) => n['id']).toList()}');
        await prefs.setString(_notificationsKey, jsonEncode(localList));
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
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
      debugPrint('Mark as read backend error: $e');
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