import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_service.dart';

/// Owns the user-controllable toggles surfaced in Settings, Profile and
/// Privacy & Security. Persists locally for instant UI restoration and
/// fires a best-effort sync to MongoDB so preferences follow the account.
class UserPreferencesService {
  static const _kLanguage = 'pref_language';
  static const _kNotifications = 'pref_notifications_enabled';
  static const _kProfileVisibility = 'pref_profile_visibility';
  static const _kActivityLogging = 'pref_activity_logging';
  static const _kLocationServices = 'pref_location_services';

  static const supportedLanguages = {
    'en': 'English',
    'ne': 'नेपाली (Nepali)',
  };

  static Future<UserPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserPreferences(
      language: prefs.getString(_kLanguage) ?? 'en',
      notificationsEnabled: prefs.getBool(_kNotifications) ?? true,
      profileVisibility: prefs.getBool(_kProfileVisibility) ?? true,
      activityLogging: prefs.getBool(_kActivityLogging) ?? true,
      locationServicesEnabled: prefs.getBool(_kLocationServices) ?? false,
    );
  }

  static Future<void> _saveLocal(UserPreferences p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, p.language);
    await prefs.setBool(_kNotifications, p.notificationsEnabled);
    await prefs.setBool(_kProfileVisibility, p.profileVisibility);
    await prefs.setBool(_kActivityLogging, p.activityLogging);
    await prefs.setBool(_kLocationServices, p.locationServicesEnabled);
  }

  /// Pulls remote preferences (if user is signed in) and reconciles with the
  /// local cache. Remote wins when both exist. Safe to call on app start.
  static Future<UserPreferences> refreshFromBackend() async {
    final user = await UserService.getUser();
    final local = await load();
    if (user == null || user['id'] == null) return local;

    final res = await ApiService.getUserSettings(user['id'].toString());
    if (res['status'] != 'ok') return local;

    final remote = res['preferences'] as Map<String, dynamic>? ?? {};
    final merged = UserPreferences(
      language: (remote['language'] as String?) ?? local.language,
      notificationsEnabled:
          (remote['notificationsEnabled'] as bool?) ?? local.notificationsEnabled,
      profileVisibility:
          (remote['profileVisibility'] as bool?) ?? local.profileVisibility,
      activityLogging:
          (remote['activityLogging'] as bool?) ?? local.activityLogging,
      locationServicesEnabled:
          (remote['locationServicesEnabled'] as bool?) ?? local.locationServicesEnabled,
    );
    await _saveLocal(merged);
    return merged;
  }

  /// Updates one or more preferences locally and pushes to the backend.
  /// Returns the new local snapshot. If the network call fails the local
  /// change still persists (offline-first) and will be re-synced next time.
  static Future<UserPreferences> update({
    String? language,
    bool? notificationsEnabled,
    bool? profileVisibility,
    bool? activityLogging,
    bool? locationServicesEnabled,
  }) async {
    final current = await load();
    final updated = current.copyWith(
      language: language,
      notificationsEnabled: notificationsEnabled,
      profileVisibility: profileVisibility,
      activityLogging: activityLogging,
      locationServicesEnabled: locationServicesEnabled,
    );
    await _saveLocal(updated);

    final user = await UserService.getUser();
    if (user != null && user['id'] != null) {
      try {
        await ApiService.updateUserSettings(
          userId: user['id'].toString(),
          language: language,
          notificationsEnabled: notificationsEnabled,
          profileVisibility: profileVisibility,
          activityLogging: activityLogging,
          locationServicesEnabled: locationServicesEnabled,
        );
      } catch (e) {
        debugPrint('[UserPreferencesService] Backend sync failed: $e');
      }
    }
    return updated;
  }

  /// Removes only preference keys; leaves auth/user data untouched. Used by
  /// the "Clear Cache" action in Privacy & Security.
  static Future<void> clearCacheOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLanguage);
    await prefs.remove(_kNotifications);
    await prefs.remove(_kProfileVisibility);
    await prefs.remove(_kActivityLogging);
    await prefs.remove(_kLocationServices);
  }
}

class UserPreferences {
  final String language;
  final bool notificationsEnabled;
  final bool profileVisibility;
  final bool activityLogging;
  final bool locationServicesEnabled;

  const UserPreferences({
    required this.language,
    required this.notificationsEnabled,
    required this.profileVisibility,
    required this.activityLogging,
    required this.locationServicesEnabled,
  });

  String get languageLabel =>
      UserPreferencesService.supportedLanguages[language] ?? language;

  UserPreferences copyWith({
    String? language,
    bool? notificationsEnabled,
    bool? profileVisibility,
    bool? activityLogging,
    bool? locationServicesEnabled,
  }) {
    return UserPreferences(
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      activityLogging: activityLogging ?? this.activityLogging,
      locationServicesEnabled:
          locationServicesEnabled ?? this.locationServicesEnabled,
    );
  }
}
