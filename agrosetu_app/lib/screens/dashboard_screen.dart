import 'package:agrosetu_app/screens/weather/weather_detail_popup.dart';
import 'package:agrosetu_app/screens/disease_detection_page.dart';
import 'package:agrosetu_app/screens/market_analytics_page.dart';
import 'package:agrosetu_app/screens/community_page.dart';
import 'package:agrosetu_app/screens/profile_page.dart';
import 'package:agrosetu_app/screens/notifications_page.dart';
import 'package:agrosetu_app/screens/voice_assistant_screen.dart';
import 'package:agrosetu_app/services/weather_service.dart';
import 'package:agrosetu_app/l10n/app_translations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import 'activities_page.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';

// ─── Color palette ───────────────────────────────────────────────────────────
class _C {
  // Background & surface
  static const bg          = Color(0xFFF5F5F0);   // warm white page bg
  static const surface     = Colors.white;

  // Green ramp (weather card, accent)
  static const greenCard   = Color(0xFF1E5C0A);   // main dark green card
  static const greenDeep   = Color(0xFF153D07);   // market card (deeper)
  static const greenLight  = Color(0xFF5A9E36);   // nav accent, FAB, badges
  static const greenMid    = Color(0xFF2D6A1F);   // section headings on white

  // Accent
  static const amber       = Color(0xFFD4831A);   // market price & trend
}
// ─────────────────────────────────────────────────────────────────────────────

// Main Dashboard with Navigation
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  List<Widget> get _pages => [
    HomeDashboard(onNavigate: _onItemTapped),
    const MarketAnalyticsPage(),
    const DiseaseDetectionPage(),
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
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(icon: const Icon(Iconsax.home),           label: 'nav.home'.tr),
      BottomNavigationBarItem(icon: const Icon(Iconsax.chart),          label: 'nav.market'.tr),
      BottomNavigationBarItem(icon: const Icon(Iconsax.camera),         label: 'nav.disease'.tr),
      BottomNavigationBarItem(icon: const Icon(Iconsax.message),        label: 'nav.community'.tr),
      BottomNavigationBarItem(icon: const Icon(Iconsax.profile_circle), label: 'nav.profile'.tr),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          items: items,
          currentIndex: _selectedIndex,
          selectedItemColor: _C.greenLight,
          unselectedItemColor: Colors.grey.shade500,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _C.surface,
          elevation: 0,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

// ─── Home Dashboard ───────────────────────────────────────────────────────────
class HomeDashboard extends StatefulWidget {
  final Function(int)? onNavigate;
  const HomeDashboard({super.key, this.onNavigate});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _recentActivities = [];

  // Fade-in + slide-up controller
  late AnimationController _entryCtrl;
  late Animation<double>    _fadeAnim;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _loadWeather();
    _loadActivities();
    _loadNotificationCount();
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    final items = await ActivityService.getRecentActivities(5);
    setState(() => _recentActivities = items);
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationService.getUnreadCount();
    setState(() => _unreadNotifications = count);
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await WeatherService.getCurrentWeather();
      setState(() {
        _weatherData = {
          'location'   : weather['location']    ?? 'Kathmandu',
          'temperature': weather['temp']         ?? 22,
          'condition'  : weather['description']  ?? 'Partly Cloudy',
          'icon'       : weather['icon']         ?? '⛅',
          'high'       : (weather['temp'] ?? 22) + 2,
          'low'        : (weather['temp'] ?? 22) - 4,
          'humidity'   : weather['humidity']     ?? '65%',
          'windSpeed'  : weather['windSpeed']    ?? '12 km/h',
        };
        _isLoadingWeather = false;
      });
    } catch (e) {
      debugPrint('Error loading weather: $e');
      setState(() => _isLoadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildWelcomeSection(),
                  const SizedBox(height: 16),
                  _buildCompactWeatherCard(),
                  const SizedBox(height: 16),
                  _buildMarketPreview(),
                  const SizedBox(height: 24),
                  _buildRecentActivities(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()),
      ),
      backgroundColor: _C.greenCard,
      elevation: 6,
      icon: const Icon(Iconsax.microphone, color: Colors.white),
      label: Text(
        'dash.ai_voice'.tr,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }

  // ── 1. TOP BAR ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo + name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.greenCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.park, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('dash.app_name'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.greenMid,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text('dash.tagline'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _C.greenMid.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Actions
          Row(
            children: [
              _buildTopBarAction(
                icon: Iconsax.notification,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  ).then((_) => _loadNotificationCount());
                },
                hasBadge: _unreadNotifications > 0,
                badgeCount: _unreadNotifications,
              ),
              // Profile icon removed from top bar — it duplicates the
              // "Profile" tab in the bottom navigation.
            ],
          ),
        ],
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
              color: _C.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: _C.greenMid),
          ),
          if (hasBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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

  // ── 2. WELCOME SECTION ─────────────────────────────────────────────────────
  Widget _buildWelcomeSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.getUser(),
      builder: (context, snapshot) {
        final userName = (snapshot.hasData && snapshot.data != null)
            ? snapshot.data!['name'] ?? 'dash.farmer_default'.tr
            : 'dash.farmer_default'.tr;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'dash.greeting_morning'.tr
            : (hour < 18 ? 'dash.greeting_afternoon'.tr : 'dash.greeting_evening'.tr);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, ✨',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('$userName!',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _C.greenMid,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.greenLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars, color: _C.greenMid, size: 14),
                          const SizedBox(width: 6),
                          Text('dash.badge_gold'.tr,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _C.greenMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tasks ring — now green
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: 0.75,
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(_C.greenLight),
                    ),
                  ),
                  Column(
                    children: [
                      Text('75%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.greenMid,
                        ),
                      ),
                      Text('dash.tasks'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
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
  }

  // ── 3. WEATHER CARD (dark green filled) ────────────────────────────────────
  Widget _buildCompactWeatherCard() {
    if (_isLoadingWeather) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: _C.greenCard,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.greenCard,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.greenCard.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative ghost cloud
          Positioned(
            right: -30,
            top: -30,
            child: Opacity(
              opacity: 0.08,
              child: const Icon(Icons.cloud, size: 220, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.location5, color: Colors.white70, size: 15),
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
                    GestureDetector(
                      onTap: () => _showWeatherPopup(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormat.MMMEd(AppTranslations.currentLocale.value).format(DateTime.now()),
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                // Temp + condition
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${_weatherData?['temperature'] ?? 22}°',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 68,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -3,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weatherData?['condition'] ?? 'dash.weather_default_condition'.tr,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'H:${_weatherData?['high'] ?? 28}° L:${_weatherData?['low'] ?? 16}°',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text('☀️', style: TextStyle(fontSize: 52)),
                  ],
                ),
                const SizedBox(height: 20),
                // Metric tiles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWeatherMetric(Iconsax.wind,  _weatherData?['windSpeed'] ?? '12 km/h', 'dash.weather_wind'.tr),
                    _buildWeatherMetric(Iconsax.drop,  _weatherData?['humidity']  ?? '65%',     'dash.weather_humidity'.tr),
                    _buildWeatherMetric(Iconsax.sun_1, 'dash.weather_uv_low'.tr,                'dash.weather_uv'.tr),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(label,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. MARKET PREVIEW (darker green filled) ────────────────────────────────
  Widget _buildMarketPreview() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _C.greenDeep,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.greenDeep.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('dash.market_trends'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.trend_up, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Price + chart
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('dash.top_tomato'.tr,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text('Rs. 120/kg',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _C.amber,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward, color: _C.greenLight, size: 12),
                        const SizedBox(width: 2),
                        Text('dash.today_change'.tr,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.greenLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 64,
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
                          color: _C.greenLight,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _C.greenLight.withValues(alpha: 0.18),
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

  // ── 6. RECENT ACTIVITIES ───────────────────────────────────────────────────
  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('dash.recent_activities'.tr,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _C.greenMid,
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ActivitiesPage()));
                _loadActivities();
              },
              child: Text('dash.see_all'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.greenLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _recentActivities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('dash.no_activity'.tr,
                      style: GoogleFonts.poppins(color: Colors.grey.shade400),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _recentActivities.length,
                  itemBuilder: (context, index) {
                    return _buildTimelineItem(
                      _recentActivities[index],
                      index == _recentActivities.length - 1,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, bool isLast) {
    final title = activity['title'] ?? '';
    final type  = activity['type']  ?? 'default';
    final iso   = activity['timestamp'] ?? DateTime.now().toIso8601String();
    final diff  = DateTime.now().difference(DateTime.parse(iso));

    final timeLabel = diff.inMinutes < 60
        ? '${diff.inMinutes}${'dash.minute_ago'.tr}'
        : diff.inHours < 24
            ? '${diff.inHours}${'dash.hour_ago'.tr}'
            : '${diff.inDays}${'dash.day_ago'.tr}';

    final IconData icon;
    final Color color;
    switch (type) {
      case 'voice':
        icon = Iconsax.microphone; color = _C.greenLight; break;
      case 'market':
        icon = Iconsax.chart_2;   color = _C.amber;       break;
      case 'disease':
        icon = Iconsax.camera;    color = const Color(0xFFC85A28); break;
      default:
        icon = Iconsax.activity;  color = Colors.grey;
    }

    return InkWell(
      onTap: () => _handleActivityTap(type),
      child: IntrinsicHeight(
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
                      BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.grey.shade100),
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
                        Expanded(
                          child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _C.greenMid,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(timeLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(type.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color.withValues(alpha: 0.7),
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
      ),
    );
  }

  void _handleActivityTap(String type) {
    switch (type) {
      case 'market':
        widget.onNavigate?.call(1);
        break;
      case 'disease':
        widget.onNavigate?.call(2);
        break;
      case 'voice':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()),
        );
        break;
      default:
        // Optional: Show message for unhandled types
        break;
    }
  }

  // ── Weather popup ──────────────────────────────────────────────────────────
  void _showWeatherPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeatherDetailPopup(),
    );
  }
}