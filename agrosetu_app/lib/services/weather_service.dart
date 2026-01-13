import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String apiKey = '53831930a3deac460b0e774eaa8b462e'; // Replace with your actual API key
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5';
  
  // For Kathmandu coordinates
  static const double lat = 27.7172;
  static const double lon = 85.3240;

  static Future<Map<String, dynamic>> getCurrentWeather() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'location': data['name'] ?? 'Kathmandu',
          'temp': data['main']['temp']?.round() ?? 22,
          'feelsLike': data['main']['feels_like']?.round() ?? 24,
          'humidity': '${data['main']['humidity']?.toString() ?? '65'}%',
          'pressure': '${data['main']['pressure']?.toString() ?? '1013'} hPa',
          'windSpeed': '${(data['wind']['speed'] ?? 3.3).toStringAsFixed(1)} km/h', // Convert m/s to km/h
          'condition': data['weather'][0]['main'] ?? 'Partly Cloudy',
          'description': data['weather'][0]['description'] ?? 'Partly cloudy',
          'rainChance': '${((data['pop'] ?? 0) * 100).toInt()}%',
          'uvIndex': '5', // OpenWeather doesn't provide UV in free tier
          'lastUpdated': DateTime.now().toIso8601String(),
          'source': 'api',
          'farmingTip': _getFarmingTip(data['main']['temp'] ?? 22, data['weather'][0]['main'] ?? 'Clear'),
          'icon': getWeatherIcon(data['weather'][0]['main'] ?? 'Clouds'),
        };
      } else {
        return _getMockData();
      }
    } catch (e) {
      print('Weather API Error: $e');
      return _getMockData();
    }
  }

  static Future<Map<String, dynamic>> getHourlyForecast() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> hourly = [];
        
        // Get next 5 hours forecast
        for (int i = 0; i < 5 && i < (data['list']?.length ?? 0); i++) {
          final forecast = data['list'][i];
          final time = DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);
          hourly.add({
            'time': '${time.hour}:00',
            'temp': forecast['main']['temp']?.round() ?? 22,
            'condition': forecast['weather'][0]['main'] ?? 'Clouds',
          });
        }
        
        return {'hourly': hourly};
      } else {
        return _getMockForecast();
      }
    } catch (e) {
      print('Forecast API Error: $e');
      return _getMockForecast();
    }
  }

  static Map<String, dynamic> _getMockData() {
    return {
      'location': 'Kathmandu',
      'temp': 22,
      'feelsLike': 24,
      'humidity': '65%',
      'pressure': '1013 hPa',
      'windSpeed': '12 km/h',
      'condition': 'Partly Cloudy',
      'description': 'Partly cloudy',
      'rainChance': '0%',
      'uvIndex': '5',
      'lastUpdated': DateTime.now().toIso8601String(),
      'source': 'mock_fallback',
      'farmingTip': 'Good day for farming activities. Perfect time for planting seasonal crops.',
      'icon': '⛅',
    };
  }

  static Map<String, dynamic> _getMockForecast() {
    return {
      'hourly': [
        {'time': 'Now', 'temp': 22, 'condition': 'Partly Cloudy'},
        {'time': '15:00', 'temp': 23, 'condition': 'Partly Cloudy'},
        {'time': '16:00', 'temp': 22, 'condition': 'Cloudy'},
        {'time': '17:00', 'temp': 21, 'condition': 'Cloudy'},
        {'time': '18:00', 'temp': 20, 'condition': 'Clear'},
      ]
    };
  }

  static String getWeatherIcon(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
        return '🌫️';
      default:
        return '⛅';
    }
  }

  static String getWeatherDescription(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Clear Sky';
      case 'clouds':
        return 'Cloudy';
      case 'rain':
        return 'Rainy';
      case 'drizzle':
        return 'Light Rain';
      case 'thunderstorm':
        return 'Thunderstorm';
      case 'snow':
        return 'Snowy';
      default:
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