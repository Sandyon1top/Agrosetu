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
import 'dart:ui'; // For BackdropFilter
import 'package:fl_chart/fl_chart.dart'; // For Market mini-chart

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
              
              // 3. MODERN WEATHER CARD
              _buildCompactWeatherCard(),
              const SizedBox(height: 24),
              
              // 4. QUICK ACTIONS GRID
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),
              
              // 5. MARKET PREVIEW
              _buildMarketPreview(),
              const SizedBox(height: 24),
              
              // 6. RECENT ACTIVITIES
              _buildRecentActivities(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ========== 1. PREMIUM TOP BAR ==========
  Widget _buildTopBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agrosetu',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B5E20),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Smart Farming',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2E7D32).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildTopBarAction(
                    icon: Iconsax.notification,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsPage()),
                      ).then((_) => _loadNotificationCount());
                    },
                    hasBadge: _unreadNotifications > 0,
                    badgeCount: _unreadNotifications,
                  ),
                  const SizedBox(width: 8),
                  _buildTopBarAction(
                    icon: Iconsax.profile_circle,
                    onTap: () {
                      // Handled by bottom nav index
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarAction({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          ),
          if (hasBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== 2. DYNAMIC WELCOME SECTION ==========
  Widget _buildWelcomeSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.getUser(),
      builder: (context, snapshot) {
        String userName = 'Farmer';
        if (snapshot.hasData && snapshot.data != null) {
          userName = snapshot.data!['name'] ?? 'Farmer';
        }
        
        final hour = DateTime.now().hour;
        final greeting = hour < 12 ? 'Good Morning' : (hour < 18 ? 'Good Afternoon' : 'Good Evening');
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, ✨',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$userName!',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B5E20),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, color: Color(0xFF2E7D32), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Gold Level Farmer',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: CircularProgressIndicator(
                      value: 0.75,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '75%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Tasks',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
   // ========== 3. MODERN WEATHER CARD ==========
  Widget _buildCompactWeatherCard() {
    if (_isLoadingWeather) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.grey.shade100,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E7D32),
            const Color(0xFF1B5E20),
            const Color(0xFF0D2D0F),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.cloud, size: 200, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Iconsax.location5, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _weatherData?['location'] ?? 'Kathmandu',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monday, 12 Oct',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showWeatherPopup(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${_weatherData?['temperature'] ?? 22}°',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weatherData?['condition'] ?? 'Mostly Sunny',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'H:28° L:16°',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text('☀️', style: TextStyle(fontSize: 48)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildModernWeatherMetric(Iconsax.wind, '12 km/h', 'Wind'),
                  _buildModernWeatherMetric(Iconsax.drop, '65%', 'Humidity'),
                  _buildModernWeatherMetric(Iconsax.sun_1, 'Low', 'UV Index'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernWeatherMetric(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ========== 6. TIMELINE RECENT ACTIVITIES ==========
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
                fontWeight: FontWeight.w700,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _recentActivities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No recent activity yet',
                      style: GoogleFonts.poppins(color: Colors.grey.shade400),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentActivities.length,
                  itemBuilder: (context, index) {
                    final activity = _recentActivities[index];
                    final isLast = index == _recentActivities.length - 1;
                    return _buildTimelineItem(activity, isLast);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, bool isLast) {
    final title = activity['title'] ?? '';
    final type = activity['type'] ?? 'default';
    final iso = activity['timestamp'] ?? DateTime.now().toIso8601String();
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    
    String timeLabel;
    if (diff.inMinutes < 60) timeLabel = '${diff.inMinutes}m ago';
    else if (diff.inHours < 24) timeLabel = '${diff.inHours}h ago';
    else timeLabel = '${diff.inDays}d ago';

    IconData icon;
    Color color;
    switch (type) {
      case 'voice':
        icon = Iconsax.microphone;
        color = Colors.blue;
        break;
      case 'market':
        icon = Iconsax.chart_2;
        color = const Color(0xFF2E7D32);
        break;
      case 'disease':
        icon = Iconsax.camera;
        color = Colors.orange;
        break;
      default:
        icon = Iconsax.activity;
        color = Colors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade100,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(icon, size: 12, color: color.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        type.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

   // ========== 4. QUICK ACTIONS GRID ==========
  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildActionCard(
              title: 'Voice Assist',
              subtitle: 'Talk to AI',
              icon: Iconsax.microphone,
              color: Colors.blue,
              onTap: () {},
            ),
            _buildActionCard(
              title: 'Smart Cam',
              subtitle: 'Scan Crop',
              icon: Iconsax.camera,
              color: Colors.orange,
              onTap: () {},
            ),
            _buildActionCard(
              title: 'Insights',
              subtitle: 'Market Analysis',
              icon: Iconsax.chart_2,
              color: const Color(0xFF2E7D32),
              onTap: () {},
            ),
            _buildActionCard(
              title: 'Forum',
              subtitle: 'Ask Community',
              icon: Iconsax.messages_1,
              color: Colors.purple,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== 5. MARKET INSIGHTS PREVIEW ==========
  Widget _buildMarketPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2D0F),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Market Trends',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Icon(Iconsax.trend_up, color: Color(0xFF4CAF50), size: 18),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top: Big Tomato',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. 120/kg',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+4.2% today',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 60,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 3),
                            FlSpot(1, 4),
                            FlSpot(2, 3.5),
                            FlSpot(3, 5),
                            FlSpot(4, 4.5),
                            FlSpot(5, 6),
                          ],
                          isCurved: true,
                          color: const Color(0xFF4CAF50),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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