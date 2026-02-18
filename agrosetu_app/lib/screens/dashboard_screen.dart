import 'package:agrosetu_app/screens/weather/weather_detail_popup.dart';
import 'package:agrosetu_app/screens/disease_detection_page_new.dart';
import 'package:agrosetu_app/screens/market_analytics_page.dart';
import 'package:agrosetu_app/screens/community_page.dart';
import 'package:agrosetu_app/screens/profile_page.dart';
import 'package:agrosetu_app/screens/notifications_page.dart';
import 'package:agrosetu_app/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import 'activities_page.dart';
import 'package:iconsax/iconsax.dart';

// Main Dashboard with Navigation
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  
  // Page list for bottom navigation
  final List<Widget> _pages = [
    const HomeDashboard(),
    const MarketAnalyticsPage(),
    const DiseaseDetectionPageNew(),
    const CommunityPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Iconsax.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.chart),
              label: 'Market',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.camera),
              label: 'Disease',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.message),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(Iconsax.profile_circle),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: Colors.grey.shade600,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

// Home Dashboard Widget
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadActivities();
    _loadNotificationCount();
  }

  List<Map<String, dynamic>> _recentActivities = [];

  Future<void> _loadActivities() async {
    final items = await ActivityService.getRecentActivities(5);
    setState(() {
      _recentActivities = items;
    });
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationService.getUnreadCount();
    setState(() {
      _unreadNotifications = count;
    });
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await WeatherService.getCurrentWeather();
      setState(() {
        _weatherData = {
          'location': weather['location'] ?? 'Kathmandu',
          'temperature': weather['temp'] ?? 22,
          'condition': weather['description'] ?? 'Partly Cloudy',
          'icon': weather['icon'] ?? '⛅',
          'high': (weather['temp'] ?? 22) + 2,
          'low': (weather['temp'] ?? 22) - 4,
          'humidity': weather['humidity'] ?? '65%',
          'windSpeed': weather['windSpeed'] ?? '12 km/h',
        };
        _isLoadingWeather = false;
      });
    } catch (e) {
      print('Error loading weather: $e');
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP BAR WITH APP NAME & PROFILE
              _buildTopBar(),
              const SizedBox(height: 16),
              
              // 2. WELCOME SECTION
              _buildWelcomeSection(),
              const SizedBox(height: 20),
              
              // 3. COMPACT WEATHER CARD
              _buildCompactWeatherCard(),
              const SizedBox(height: 20),
              
              // 4. VOICE ASSISTANT
              _buildVoiceAssistant(),
              const SizedBox(height: 20),
              
              // 5. RECENT ACTIVITIES
              _buildRecentActivities(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 1. TOP BAR WITH APP NAME & PROFILE ==========
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Agrosetu App Name on very top left (only one)
          Row(
            children: [
              Icon(
                Icons.agriculture,
                color: Color(0xFF2E7D32),
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Agrosetu',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          // Notification and Profile icons
          Row(
            children: [
              // Notification bell
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Iconsax.notification,
                      size: 24,
                      color: Color(0xFF2E7D32),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      ).then((_) {
                        _loadNotificationCount();
                      });
                    },
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Profile icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF2E7D32),
                    width: 1.5,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Iconsax.profile_circle,
                    size: 22,
                    color: Color(0xFF2E7D32),
                  ),
                  onPressed: () {
                    // Profile is accessible via bottom nav
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== 2. WELCOME SECTION ==========
  Widget _buildWelcomeSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.getUser(),
      builder: (context, snapshot) {
        String userName = 'Farmer';
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state
          userName = 'Farmer';
        } else if (snapshot.hasData && snapshot.data != null) {
          // Show actual user name
          userName = snapshot.data!['name'] ?? 'Farmer';
          print('[Dashboard] Welcome section - User: $userName');
        } else if (snapshot.hasError) {
          print('[Dashboard] Error loading user: ${snapshot.error}');
        }
        
        final hour = DateTime.now().hour;
        final greeting = hour < 12 ? 'Good Morning' : (hour < 18 ? 'Good Afternoon' : 'Good Evening');
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting,',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$userName! 👋',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s your farming summary today',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      },
    );
  }

  // ========== 3. COMPACT WEATHER CARD ==========
  Widget _buildCompactWeatherCard() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E20).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading weather...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_weatherData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E20).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Unable to load weather',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showWeatherPopup(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E20).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location row (NO Agrosetu here)
            Row(
              children: [
                Icon(Iconsax.location, size: 16, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  _weatherData?['location'] ?? 'Kathmandu',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap for details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Main weather info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temperature (big)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weatherData?['temperature'] ?? 22}°',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'H:${_weatherData?['high'] ?? 24}° L:${_weatherData?['low'] ?? 18}°',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 20),
                
                // Weather icon and condition
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weatherData?['icon'] ?? '⛅',
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weatherData?['condition'] ?? 'Loading...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Feels like ${((_weatherData?['temperature'] ?? 22) + 2)}°',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWeatherMetric('Wind', _weatherData?['windSpeed'] ?? '12 km/h', Iconsax.wind),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildWeatherMetric('Humidity', _weatherData?['humidity'] ?? '65%', Iconsax.drop),
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildWeatherMetric('Sunset', _weatherData?['sunset'] ?? '6:45 PM', Iconsax.moon),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (_weatherData?['farmingTip'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _weatherData?['farmingTip'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ========== 4. VOICE ASSISTANT ==========
  Widget _buildVoiceAssistant() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Action',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Iconsax.microphone,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Assistant',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Ask for farming advice',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.arrow_right_3),
                  onPressed: () async {
                    await ActivityService.addActivity('voice', 'Voice advice taken');
                    await _loadActivities();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Voice Assistant', style: GoogleFonts.poppins()),
                        content: Text('Voice assistant launched', style: GoogleFonts.poppins()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 5. RECENT ACTIVITIES ==========
  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activities',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitiesPage()));
                _loadActivities();
              },
              child: Text(
                'See all',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _recentActivities.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No recent activity', style: GoogleFonts.poppins()),
                    )
                  ]
                : _recentActivities.map((activity) {
                    final title = activity['title'] ?? '';
                    final iso = activity['timestamp'] ?? DateTime.now().toIso8601String();
                    final dt = DateTime.parse(iso);
                    final diff = DateTime.now().difference(dt);
                    String timeLabel;
                    if (diff.inMinutes < 60) timeLabel = '${diff.inMinutes} min ago';
                    else if (diff.inHours < 24) timeLabel = '${diff.inHours} hour(s) ago';
                    else timeLabel = '${diff.inDays} day(s) ago';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Iconsax.timer_1,
                              size: 18,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  timeLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Iconsax.arrow_right_3,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }

  void _showWeatherPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WeatherDetailPopup(),
    );
  }
}