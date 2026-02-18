import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/activity_service.dart';

class MarketAnalyticsPage extends StatefulWidget {
  const MarketAnalyticsPage({super.key});

  @override
  State<MarketAnalyticsPage> createState() => _MarketAnalyticsPageState();
}

class _MarketAnalyticsPageState extends State<MarketAnalyticsPage> {
  List<Map<String, dynamic>> _commodityData = [];
  List<String> _commodities = [];
  String _selectedCrop = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ActivityService.addActivity('market', 'Viewed market analytics');
    _loadCsvData();
  }

  Future<void> _loadCsvData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('commodity_data_cache');
      
      // If cached data exists, use it
      if (cachedData != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedData);
        final List<Map<String, dynamic>> data = (decoded['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        final List<String> commodities = List<String>.from(decoded['commodities'] as List);
        
        setState(() {
          _commodityData = data;
          _commodities = commodities;
          _selectedCrop = _commodities.isNotEmpty ? _commodities[0] : '';
          _isLoading = false;
        });
        return;
      }
      
      // Load and parse CSV
      final csvContent = await rootBundle.loadString('data/Kalimati_Tarkari_Dataset.csv');
      final lines = csvContent.split('\n');
      
      final Map<String, List<Map<String, double>>> commodityRecords = {};
      
      // Parse CSV (skip header)
      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        
        final parts = lines[i].split(',');
        if (parts.length < 6) continue;
        
        final commodity = parts[0].trim();
        final minimum = double.tryParse(parts[3].trim()) ?? 0;
        final maximum = double.tryParse(parts[4].trim()) ?? 0;
        final average = double.tryParse(parts[5].trim()) ?? 0;
        
        if (!commodityRecords.containsKey(commodity)) {
          commodityRecords[commodity] = [];
        }
        commodityRecords[commodity]!.add({
          'minimum': minimum,
          'maximum': maximum,
          'average': average,
        });
      }
      
      // Calculate aggregated data
      final List<Map<String, dynamic>> aggregatedData = [];
      final List<String> commodityNames = commodityRecords.keys.toList()..sort();
      
      for (final commodity in commodityNames) {
        final records = commodityRecords[commodity]!;
        
        // Calculate averages across all dates
        double avgMin = 0, avgMax = 0, avgAvg = 0;
        for (final record in records) {
          avgMin += record['minimum']!;
          avgMax += record['maximum']!;
          avgAvg += record['average']!;
        }
        avgMin /= records.length;
        avgMax /= records.length;
        avgAvg /= records.length;
        
        aggregatedData.add({
          'commodity': commodity,
          'minimum': avgMin,
          'maximum': avgMax,
          'average': avgAvg,
        });
      }
      
      // Cache the data
      await prefs.setString('commodity_data_cache', jsonEncode({
        'data': aggregatedData,
        'commodities': commodityNames,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      setState(() {
        _commodityData = aggregatedData;
        _commodities = commodityNames;
        _selectedCrop = _commodities.isNotEmpty ? _commodities[0] : '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading CSV: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getSelectedCommodityData() {
    try {
      return _commodityData.firstWhere((item) => item['commodity'] == _selectedCrop);
    } catch (e) {
      return null;
    }
  }

  // Calculate price change percentage
  double _getPriceChange(String crop) {
    final data = _getSelectedCommodityData();
    if (data == null) return 0;
    final change = ((data['maximum'] - data['minimum']) / data['minimum']) * 100;
    return change;
  }

  // Get line chart data for the selected crop
  LineChartData _getLineChartData() {
    final data = _getSelectedCommodityData();
    if (data == null) {
      return LineChartData(
        lineBarsData: [],
        titlesData: FlTitlesData(),
      );
    }

    final spots = [
      FlSpot(0, (data['minimum'] as double)),
      FlSpot(1, (data['average'] as double)),
      FlSpot(2, (data['maximum'] as double)),
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 10,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: (value, meta) {
              return Text(
                'Rs.${value.toInt()}',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final labels = ['Min', 'Avg', 'Max'];
              final index = value.toInt();
              if (index >= 0 && index < labels.length) {
                return Text(
                  labels[index],
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      minX: 0,
      maxX: 2,
      minY: (data['minimum'] as double) - 5,
      maxY: (data['maximum'] as double) + 5,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFF2E7D32),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: const Color(0xFF2E7D32),
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF2E7D32).withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_commodities.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(child: Text('No commodity data available')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Price Trends
              _buildPriceTrends(),
              
              // Crop Selector
              _buildCropSelector(),
              
              // Price Data Table
              _buildPriceTable(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Iconsax.chart,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Market Analytics',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Historical crop price trends (2018-2024)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTrends() {
    final data = _getSelectedCommodityData();
    if (data == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Trends - ${_selectedCrop}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: LineChart(
                  _getLineChartData(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Current market stats - Fixed overflow with Wrap
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: _StatItem(
                  title: 'Minimum',
                  value: 'Rs. ${(data['minimum'] as double).toInt()}',
                  change: '${_getPriceChange(_selectedCrop).toStringAsFixed(1)}% range',
                  isPositive: true,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: _StatItem(
                  title: 'Average',
                  value: 'Rs. ${(data['average'] as double).toInt()}',
                  change: 'per kg',
                  isPositive: true,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: _StatItem(
                  title: 'Maximum',
                  value: 'Rs. ${(data['maximum'] as double).toInt()}',
                  change: 'peak price',
                  isPositive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCropSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _commodities.map((crop) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                label: Text(
                  crop,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                selected: _selectedCrop == crop,
                onSelected: (selected) {
                  setState(() => _selectedCrop = crop);
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF2E7D32).withOpacity(0.15),
                labelStyle: GoogleFonts.poppins(
                  color: _selectedCrop == crop 
                    ? const Color(0xFF2E7D32) 
                    : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: _selectedCrop == crop 
                    ? const Color(0xFF2E7D32) 
                    : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPriceTable() {
    return Container(
      margin: const EdgeInsets.all(20),
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
            'All Commodities',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 16),
          
          // Simplified list view with proper constraints
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _commodityData.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.grey.shade200,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final data = _commodityData[index];
              final commodity = data['commodity'] as String;
              final average = (data['average'] as double).toInt();
              final minimum = (data['minimum'] as double).toInt();
              final maximum = (data['maximum'] as double).toInt();
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                commodity,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rs. $average/kg avg',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Min: $minimum',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Max: $maximum',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
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
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;

  const _StatItem({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                color: isPositive ? Colors.green : Colors.red,
                size: 11,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  change,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}