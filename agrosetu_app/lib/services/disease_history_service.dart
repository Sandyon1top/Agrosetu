import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class DiseaseHistoryService {
  static const String _key = 'disease_history_cache';

  static Future<void> addDetection(String disease, String confidence, List<String> solutions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_key);
      
      List<dynamic> history = [];
      if (existingData != null) {
        history = json.decode(existingData) as List<dynamic>;
      }

      final newDetection = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'disease': disease,
        'confidence': confidence,
        'solutions': solutions,
        'date': DateTime.now().toIso8601String(),
        'synced': false,
      };

      history.insert(0, newDetection);
      await prefs.setString(_key, json.encode(history));
      
      _trySync(history);
    } catch (e) {
      debugPrint('Error saving detection history: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_key);
      
      if (existingData != null) {
        final List<dynamic> decoded = json.decode(existingData);
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Error reading detection history: $e');
    }
    return [];
  }

  static Future<void> _trySync(List<dynamic> currentHistory) async {
    try {
      final unsynced = currentHistory.where((item) => item['synced'] == false).toList();
      if (unsynced.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final userDataRaw = prefs.getString('user_data');
      if (userDataRaw == null) return;
      final userData = json.decode(userDataRaw) as Map<String, dynamic>;
      final userId = userData['id'] as String?;
      if (userId == null) return;

      final response = await ApiService.syncDiseaseHistory(userId, unsynced);
      if (response['status'] == 'ok') {
        final updatedHistory = currentHistory.map((item) {
          if (unsynced.any((u) => u['id'] == item['id'])) {
            item['synced'] = true;
          }
          return item;
        }).toList();

        await prefs.setString(_key, json.encode(updatedHistory));
        debugPrint('✅ Offline detections synced dynamically to MongoDB');
      }
    } catch (e) {
      debugPrint('Sync skipped: offline or error ($e)');
    }
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> syncPendingDetections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString(_key);
      if (existingData != null) {
        final List<dynamic> history = json.decode(existingData) as List<dynamic>;
        await _trySync(history);
      }
    } catch (e) {
      debugPrint('Manual sync error: $e');
    }
  }
}
