import 'package:flutter/material.dart';
import '../../../services/weather_service.dart';

class WeatherDetailPopup extends StatefulWidget {
  const WeatherDetailPopup({super.key});

  @override
  _WeatherDetailPopupState createState() => _WeatherDetailPopupState();
}

class _WeatherDetailPopupState extends State<WeatherDetailPopup> {
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _hourlyForecast;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    try {
      final weather = await WeatherService.getCurrentWeather();
      final forecast = await WeatherService.getHourlyForecast();
      
      setState(() {
        _weatherData = weather;
        _hourlyForecast = forecast;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      setState(() {
        _isLoading = false;
        _weatherData = {
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
          'source': 'mock',
          'farmingTip': 'Good day for farming activities.',
          'icon': '⛅',
        };
        _hourlyForecast = {
          'hourly': [
            {'time': 'Now', 'temp': 22, 'condition': 'Clouds'},
            {'time': '15:00', 'temp': 23, 'condition': 'Clouds'},
            {'time': '18:00', 'temp': 22, 'condition': 'Clouds'},
          ]
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: _isLoading
              ? _buildLoading()
              : _buildWeatherContent(scrollController),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading weather...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent(ScrollController scrollController) {
    final weather = _weatherData!;
    final hourly = _hourlyForecast?['hourly'] ?? [];

    return Column(
      children: [
        // Handle
        Container(
          margin: EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weather Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '📍 ${weather['location']}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Main weather card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2E7D32),
                        Color(0xFF1B5E20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Temperature and icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weather['icon'] ?? '⛅',
                            style: TextStyle(fontSize: 50),
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${weather['temp']}°C',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                weather['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Weather stats - 2 rows of 3 for mobile
                      Column(
                        children: [
                          // First row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMobileStat('Humidity', weather['humidity'], Icons.water_drop),
                              _buildMobileStat('Wind', weather['windSpeed'], Icons.air),
                              _buildMobileStat('Rain', weather['rainChance'], Icons.beach_access),
                            ],
                          ),
                          
                          SizedBox(height: 12),
                          
                          // Second row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMobileStat('Feels like', '${weather['feelsLike']}°C', Icons.thermostat),
                              _buildMobileStat('Pressure', weather['pressure'], Icons.speed),
                              _buildMobileStat('UV Index', weather['uvIndex'], Icons.wb_sunny),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Hourly Forecast
                Text(
                  "Today's Forecast",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 12),
                
                
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hourly.length,
                    itemBuilder: (context, index) {
                      final hour = hourly[index];
                      return Container(
                        width: 75,
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: index == 0 ? Colors.blue[100]! : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              hour['time'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: index == 0 ? Colors.blue[800] : Colors.grey[700],
                              ),
                            ),
                            Text(
                              WeatherService.getWeatherIcon(hour['condition']),
                              style: TextStyle(fontSize: 20),
                            ),
                            Text(
                              '${hour['temp']}°',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Farming Tip
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.eco, color: Colors.green[700], size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🌱 Farming Tip',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              weather['farmingTip'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Footer
                Container(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last updated',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Just now',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: weather['source'] == 'api' ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          weather['source'] == 'api' ? 'LIVE DATA' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Refresh button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadWeatherData,
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text('Refresh Weather'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStat(String label, String value, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 72) / 3, // Responsive width
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}