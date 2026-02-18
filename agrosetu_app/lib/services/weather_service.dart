import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherService {
  static const String backendUrl = 'http://localhost:5001';
  static const double lat = 27.7172;
  static const double lon = 85.3240;

  static Future<Map<String, dynamic>> getCurrentWeather() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/weather/current?lat=$lat&lon=$lon'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final condition = data['condition'] ?? 'cloudy';
        String sunset = '';
        try {
          if (data['sunsetEpoch'] != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch((data['sunsetEpoch'] as int) * 1000);
            sunset = DateFormat('h:mm a').format(dt);
          }
        } catch (e) {
          sunset = '';
        }

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
          'uvIndex': '5',
          'lastUpdated': data['lastUpdated'] ?? DateTime.now().toIso8601String(),
          'source': data['source'] ?? 'api',
          'farmingTip': data['farmingTip'] ?? 'Good day for farming activities.',
          'icon': getWeatherIcon(condition),
          'sunset': sunset,
        };
      } else {
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      print('Weather API Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getHourlyForecast() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/weather/hourly?lat=$lat&lon=$lon'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> hourly = [];
        
        if (data['hourly'] is List) {
          for (var forecast in data['hourly']) {
            hourly.add({
              'time': forecast['time'] ?? 'N/A',
              'temp': forecast['temp'] ?? 22,
              'condition': forecast['condition'] ?? 'cloudy',
            });
          }
        }
        
        if (hourly.isEmpty) {
          throw Exception('No hourly forecast data received');
        }

        return {'hourly': hourly};
      } else {
        throw Exception('Failed to fetch forecast: ${response.statusCode}');
      }
    } catch (e) {
      print('Forecast API Error: $e');
      rethrow;
    }
  }

  @deprecated
  static Map<String, dynamic> _getMockData() {
    throw Exception('Mock data removed');
  }

  @deprecated
  static Map<String, dynamic> _getMockForecast() {
    throw Exception('Mock forecast removed');
  }

  static String getWeatherIcon(String condition) {
    final cond = condition.toLowerCase();
    if (cond.contains('clear') || cond.contains('sunny')) {
      return '☀️';
    } else if (cond.contains('cloud') || cond.contains('cloudy')) {
      return '☁️';
    } else if (cond.contains('rain')) {
      return '🌧️';
    } else if (cond.contains('drizzle')) {
      return '🌦️';
    } else if (cond.contains('thunder') || cond.contains('storm')) {
      return '⛈️';
    } else if (cond.contains('snow')) {
      return '❄️';
    } else if (cond.contains('mist') || cond.contains('fog')) {
      return '🌫️';
    } else {
      return '⛅';
    }
  }

  static String getWeatherDescription(String condition) {
    final cond = condition.toLowerCase();
    if (cond.contains('clear') || cond.contains('sunny')) {
      return 'Clear Sky';
    } else if (cond.contains('cloud')) {
      return 'Few Clouds';
    } else if (cond.contains('rain')) {
      return 'Rainy';
    } else if (cond.contains('drizzle')) {
      return 'Light Rain';
    } else if (cond.contains('thunder') || cond.contains('storm')) {
      return 'Thunderstorm';
    } else if (cond.contains('snow')) {
      return 'Snowy';
    } else {
      return 'Partly Cloudy';
    }
  }

  static String _getFarmingTip(double temp, String condition) {
    if (temp > 30) {
      return 'Hot day! Water crops in early morning or late evening to avoid evaporation.';
    } else if (temp < 10) {
      return 'Cold weather. Protect sensitive plants with covers or move them indoors.';
    } else if (condition.toLowerCase().contains('rain')) {
      return 'Rainy day. Good for natural irrigation. Check drainage to prevent waterlogging.';
    } else if (condition.toLowerCase().contains('clear')) {
      return 'Perfect sunny day for harvesting and outdoor farm activities.';
    } else {
      return 'Good day for farming activities. Perfect time for planting seasonal crops.';
    }
  }
}