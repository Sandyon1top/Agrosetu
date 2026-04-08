import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  // Update this to your machine's IP if testing on a real device
  static const String backendUrl = 'http://localhost:5001';
  static const String _cacheKey = 'agro_weather_cache';
  static const String _forecastKey = 'agro_forecast_cache';

  /// Fetches current weather. 
  /// Priority: API -> If fails, returns Local Cache.
  static Future<Map<String, dynamic>> getCurrentWeather({String? query}) async {
    try {
      final url = query != null 
          ? '$backendUrl/api/weather/current?city=${Uri.encodeComponent(query)}'
          : '$backendUrl/api/weather/current?lat=27.7172&lon=85.3240';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final formattedData = _formatWeatherResponse(data, source: 'api');
        
        // Save to cache for offline use
        await _saveToCache(_cacheKey, formattedData);
        return formattedData;
      } else {
        return await getCachedWeather();
      }
    } catch (e) {
      debugPrint('Weather Service Error: $e');
      return await getCachedWeather();
    }
  }

  /// Fetches 7-Day Forecast
  static Future<List<dynamic>> get7DayForecast({String? query}) async {
    try {
      final url = query != null 
          ? '$backendUrl/api/weather/forecast?city=${Uri.encodeComponent(query)}&days=7'
          : '$backendUrl/api/weather/forecast?lat=27.7172&lon=85.3240&days=7';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List forecastList = json.decode(response.body) as List;
        
        // Cache the list
        await _saveToCache(_forecastKey, {'list': forecastList});
        return forecastList;
      } else {
        final cached = await _getCache(_forecastKey);
        return cached?['list'] ?? [];
      }
    } catch (e) {
      final cached = await _getCache(_forecastKey);
      return cached?['list'] ?? [];
    }
  }

  /// Formats raw API data into the UI-friendly Map used in your Popup
  static Map<String, dynamic> _formatWeatherResponse(Map<String, dynamic> data, {required String source}) {
    final condition = data['condition'] ?? 'cloudy';
    return {
      'location': data['location'] ?? 'Kathmandu',
      'temp': data['temp'] ?? 22,
      'feelsLike': data['feelsLike'] ?? 24,
      'humidity': '${data['humidity']?.toString() ?? '65'}%',
      'windSpeed': '${data['windSpeed'] ?? 12} km/h',
      'condition': condition,
      'description': getWeatherDescription(condition),
      'pressure': '${data['pressure']?.toString() ?? '1013'} hPa',
      'rainChance': '${data['rainChance']?.toString() ?? '0'}%',
      'uvIndex': data['uvIndex']?.toString() ?? '5',
      'lastUpdated': DateTime.now().toIso8601String(),
      'source': source,
      'farmingTip': data['farmingTip'] ?? 'Good day for farming activities.',
      'icon': getWeatherIcon(condition),
    };
  }

  // --- Persistence Logic ---

  static Future<void> _saveToCache(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(data));
  }

  static Future<Map<String, dynamic>?> _getCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return json.decode(raw);
  }

  static Future<Map<String, dynamic>> getCachedWeather() async {
    final cached = await _getCache(_cacheKey);
    if (cached != null) {
      cached['source'] = 'offline'; // Mark as offline for UI indicator
      return cached;
    }
    // Final fallback if no cache exists
    return {
      'location': 'No Connection',
      'temp': '--',
      'description': 'Offline Mode',
      'source': 'offline',
      'icon': '❓',
      'farmingTip': 'Connect to internet to get latest updates.',
      'humidity': '0%', 'windSpeed': '0', 'rainChance': '0%', 'feelsLike': '--', 'pressure': '--', 'uvIndex': '--'
    };
  }

  // --- UI Helpers ---

  static String getWeatherIcon(String condition) {
    final cond = condition.toLowerCase();
    if (cond.contains('clear') || cond.contains('sunny')) return '☀️';
    if (cond.contains('cloud')) return '☁️';
    if (cond.contains('rain')) return '🌧️';
    if (cond.contains('thunder')) return '⛈️';
    if (cond.contains('snow')) return '❄️';
    return '⛅';
  }

  static String getWeatherDescription(String condition) {
    final cond = condition.toLowerCase();
    if (cond.contains('clear')) return 'Clear Sky';
    if (cond.contains('cloud')) return 'Partly Cloudy';
    if (cond.contains('rain')) return 'Rainy';
    return 'Partly Cloudy';
  }
}