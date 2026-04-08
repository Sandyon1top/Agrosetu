import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/weather_service.dart';

class WeatherDetailPopup extends StatefulWidget {
  const WeatherDetailPopup({super.key});

  @override
  _WeatherDetailPopupState createState() => _WeatherDetailPopupState();
}

class _WeatherDetailPopupState extends State<WeatherDetailPopup> {
  Map<String, dynamic>? _weatherData;
  List<dynamic>? _dailyForecast; 
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWeatherData(); 
  }

  Future<void> _loadWeatherData({String? query}) async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch current weather and 7-day forecast from updated WeatherService
      final weather = await WeatherService.getCurrentWeather(query: query);
      final forecast = await WeatherService.get7DayForecast(query: query ?? weather['location']);

      setState(() {
        _weatherData = weather;
        _dailyForecast = forecast;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      // 2. Offline Fallback Logic
      final cached = await WeatherService.getCachedWeather();
      setState(() {
        _weatherData = cached;
        _dailyForecast = cached['dailyForecast'] ?? []; 
        _isLoading = false;
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _weatherData == null
                        ? _buildErrorContent()
                        : _buildWeatherContent(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search location (e.g. Kathmandu)',
          prefixIcon: Icon(Icons.search, color: Colors.green),
          suffixIcon: IconButton(
            icon: Icon(Icons.send),
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _loadWeatherData(query: _searchController.text);
                FocusScope.of(context).unfocus(); // Close keyboard
              }
            },
          ),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (val) {
          if (val.isNotEmpty) _loadWeatherData(query: val);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: 12, bottom: 8),
          width: 40, height: 5,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weather Forecast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherContent(ScrollController scrollController) {
    final weather = _weatherData!;
    final daily = _dailyForecast ?? [];

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('📍 ${weather['location']}', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ),
          SizedBox(height: 15),
          
          _buildMainCard(weather),
          
          SizedBox(height: 25),
          
          Text("7-Day Forecast", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          SizedBox(height: 12),
          
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: daily.length,
            itemBuilder: (context, index) {
              final day = daily[index];
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        index == 0 ? "Today" : DateFormat('EEEE').format(DateTime.parse(day['date'])),
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                    ),
                    Text(WeatherService.getWeatherIcon(day['condition']), style: TextStyle(fontSize: 22)),
                    Row(
                      children: [
                        Text('${day['maxTemp']}°', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 8),
                        Text('${day['minTemp']}°', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          _buildFarmingTip(weather['farmingTip']),
          _buildFooter(weather),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMainCard(Map weather) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(weather['icon'] ?? '⛅', style: TextStyle(fontSize: 50)),
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${weather['temp']}°C', style: TextStyle(fontSize: 35, color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(weather['description'], style: TextStyle(color: Colors.white.withOpacity(0.8))),
                ],
              )
            ],
          ),
          Divider(color: Colors.white24, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMobileStat('Humidity', weather['humidity'], Icons.water_drop),
              _buildMobileStat('Wind', weather['windSpeed'], Icons.air),
              _buildMobileStat('Rain', weather['rainChance'], Icons.umbrella),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildFarmingTip(String tip) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, color: Colors.green[700]),
          SizedBox(width: 12),
          Expanded(
            child: Text(tip, style: TextStyle(color: Colors.green[900], fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Map weather) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Updated: ${DateFormat('hh:mm a').format(DateTime.now())}", style: TextStyle(color: Colors.grey, fontSize: 12)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: weather['source'] == 'api' ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              weather['source'] == 'api' ? "LIVE" : "OFFLINE",
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 16),
          Text('Fetching weather...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 50, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text('Connection Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _loadWeatherData(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Retry'),
          )
        ],
      ),
    );
  }
}