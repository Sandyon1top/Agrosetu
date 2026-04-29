import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../l10n/app_translations.dart';
import '../../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _health;
  List<Map<String, dynamic>> _series = [];
  bool _loading = true;
  String? _error;

  static const _green = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.adminGetStats(),
      ApiService.adminGetTimeseries(days: 30),
    ]);
    if (!mounted) return;

    final s = results[0];
    final t = results[1];

    if (s['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = s['message']?.toString() ?? 'Failed to load stats';
      });
      return;
    }

    setState(() {
      _stats = Map<String, dynamic>.from(s['stats'] ?? {});
      _health = Map<String, dynamic>.from(s['health'] ?? {});
      _series = t['status'] == 'ok'
          ? List<Map<String, dynamic>>.from(t['series'] ?? [])
          : [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.warning_2, color: Colors.red.shade400, size: 36),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                style:
                    ElevatedButton.styleFrom(backgroundColor: _green),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats ?? {};
    final health = _health ?? {};

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin.subtitle'.tr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            _statsGrid(stats),
            const SizedBox(height: 16),
            _healthRow(health),
            const SizedBox(height: 20),
            _chartCard(),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(Map<String, dynamic> s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statCard('admin.total_users'.tr,
            (s['totalUsers'] ?? 0).toString(), Iconsax.profile_2user, _green),
        _statCard('admin.active_users'.tr,
            (s['activeUsers'] ?? 0).toString(), Iconsax.tick_circle, Colors.blue.shade700),
        _statCard('admin.posts_count'.tr,
            (s['totalPosts'] ?? 0).toString(), Iconsax.message, Colors.purple.shade700),
        _statCard('admin.detections_count'.tr,
            (s['totalDetections'] ?? 0).toString(), Iconsax.health, Colors.orange.shade700),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow(Map<String, dynamic> h) {
    return Column(
      children: [
        _healthCard(
          'admin.health_mongo'.tr,
          h['mongodb'] == true,
          extra: null,
        ),
        const SizedBox(height: 8),
        _healthCard(
          'admin.health_flask'.tr,
          h['flask'] == true,
          extra: h['flaskLatencyMs'] != null
              ? '${h['flaskLatencyMs']}ms'
              : null,
        ),
        const SizedBox(height: 8),
        _healthCard(
          'admin.health_groq'.tr,
          h['groqConfigured'] == true,
          extra: null,
        ),
      ],
    );
  }

  Widget _healthCard(String label, bool ok, {String? extra}) {
    final color = ok ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  ok ? 'admin.online'.tr : 'admin.offline'.tr,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (extra != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                extra,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.detections_30d'.tr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            'admin.detections_30d_sub'.tr,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _series.isEmpty ? _emptyChart() : _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() {
    return Center(
      child: Text(
        'admin.empty_detections'.tr,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _series.length; i++) {
      final count = (_series[i]['count'] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), count));
    }
    final maxY = spots.isEmpty
        ? 5.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 4,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY / 4).clamp(1, double.infinity),
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: GoogleFonts.robotoMono(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (_series.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _series.length) return const SizedBox();
                final date = _series[idx]['date']?.toString() ?? '';
                final mmdd = date.length >= 10 ? date.substring(5) : date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    mmdd,
                    style: GoogleFonts.robotoMono(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _green,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: _green,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _green.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
