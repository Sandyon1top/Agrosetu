import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserService {
  static const String _userKey = 'user_data';
  static const String _profileImageKey = 'profile_image_base64';
  
  // In-memory cache to ensure immediate availability
  static Map<String, dynamic>? _cachedUser;
  
  // Initialize UserService on app startup
  static Future<void> initialize() async {
    final user = await getUser();
    if (user != null) {
      print('[UserService] Initialized with cached user: ${user['name']}');
    } else {
      print('[UserService] No cached user found');
    }
  }

  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
    // Update cache immediately
    _cachedUser = userData;
    print('[UserService] User saved: ${userData['name'] ?? 'Unknown'}');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    // Return cached user if available
    if (_cachedUser != null) {
      print('[UserService] Returning cached user: ${_cachedUser!['name'] ?? 'Unknown'}');
      return _cachedUser;
    }
    
    // Otherwise, load from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) {
      print('[UserService] No user data found in storage');
      return null;
    }
    try {
      final user = jsonDecode(userJson) as Map<String, dynamic>;
      _cachedUser = user; // Update cache
      print('[UserService] User loaded from storage: ${user['name'] ?? 'Unknown'}');
      return user;
    } catch (e) {
      print('[UserService] Error decoding user: $e');
      return null;
    }
  }

  static Future<void> updateUser(Map<String, dynamic> updates) async {
    final user = await getUser();
    if (user == null) return;
    final updated = {...user, ...updates};
    await saveUser(updated);
  }

  static Future<void> saveProfileImage(String base64Image) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey, base64Image);
  }

  static Future<String?> getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileImageKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_profileImageKey);
    _cachedUser = null; // Clear cache
    print('[UserService] User logged out, cache cleared');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _cachedUser = null; // Clear cache
    print('[UserService] All data cleared');
  }
}
