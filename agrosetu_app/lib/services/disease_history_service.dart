import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class DiseaseHistoryService {
  static const String _key = 'disease_history_cache';

  /// Add a detection to the local history cache.
  /// It automatically sets `synced: false`.
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

      history.insert(0, newDetection); // Newest first
      await prefs.setString(_key, json.encode(history));
      
      // Attempt to sync immediately
      _trySync(history);
    } catch (e) {
      debugPrint('Error saving detection history: $e');
    }
  }

  /// Retrieves the local history. Optionally limits the amount.
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

  /// Cloud synchronization. Tries to upload unsynced items to the cloud.
  static Future<void> _trySync(List<dynamic> currentHistory) async {
    try {
      final unsynced = currentHistory.where((item) => item['synced'] == false).toList();
      if (unsynced.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return; // User must be logged in

      final response = await ApiService.syncDiseaseHistory(userId, unsynced);
      if (response['status'] == 'ok') {
        // Mark all as synced
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

  /// Sync manually (call this on App Startup or when internet reconnects)
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
