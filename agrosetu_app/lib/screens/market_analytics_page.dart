import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class MarketAnalyticsPage extends StatefulWidget {
  const MarketAnalyticsPage({super.key});

  @override
  State<MarketAnalyticsPage> createState() => _MarketAnalyticsPageState();
}

class _MarketAnalyticsPageState extends State<MarketAnalyticsPage> {
  String _selectedCrop = 'Rice';
  final List<String> _crops = ['Rice', 'Wheat', 'Corn', 'Potato', 'Onion'];

  // Current market prices in NPR
  final Map<String, double> _currentPrices = {
    'Rice': 2450,
    'Wheat': 2100,
    'Corn': 1950,
    'Potato': 1200,
    'Onion': 1800,
  };

  // Historical data for trends
  final List<Map<String, dynamic>> _priceHistory = [
    {'year': 2018, 'rice': 1800, 'wheat': 1600, 'corn': 1400},
    {'year': 2019, 'rice': 1950, 'wheat': 1750, 'corn': 1550},
    {'year': 2020, 'rice': 2050, 'wheat': 1850, 'corn': 1650},
    {'year': 2021, 'rice': 2200, 'wheat': 1950, 'corn': 1750},
    {'year': 2022, 'rice': 2350, 'wheat': 2050, 'corn': 1900},
    {'year': 2023, 'rice': 2400, 'wheat': 2080, 'corn': 1920},
    {'year': 2024, 'rice': 2450, 'wheat': 2100, 'corn': 1950},
  ];

  // Calculate price change percentage
  double _getPriceChange(String crop) {
    final current = _currentPrices[crop] ?? 0;
    final previous = _priceHistory[_priceHistory.length - 2][crop.toLowerCase()] ?? current;
    return ((current - previous) / previous * 100);
  }

  @override
  Widget build(BuildContext context) {
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
            'Price Trends',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Iconsax.chart,
                    size: 50,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Price Chart Visualization',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                    ),
                  ),
                  Text(
                    'Line/Bar charts showing trends',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Current market stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                title: 'Current',
                value: 'Rs. ${_currentPrices[_selectedCrop]?.toInt()}',
                change: '${_getPriceChange(_selectedCrop) >= 0 ? '+' : ''}${_getPriceChange(_selectedCrop).toStringAsFixed(1)}%',
                isPositive: _getPriceChange(_selectedCrop) >= 0,
              ),
              _StatItem(
                title: 'Avg Trend',
                value: '↑ 8.2%',
                change: 'per year',
                isPositive: true,
              ),
              _StatItem(
                title: 'Best Month',
                value: 'November',
                change: '+15%',
                isPositive: true,
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
          children: _crops.map((crop) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterChip(
                label: Text(crop),
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
            'Price History (2018-2024)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 16),
          
          // Simplified list view instead of table
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _priceHistory.length,
            separatorBuilder: (_, __) => Divider(
              color: Colors.grey.shade200,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final data = _priceHistory[index];
              final ricePrice = data['rice'] as int;
              final wheatPrice = data['wheat'] as int;
              final cornPrice = data['corn'] as int;
              
              // Calculate growth from first year
              final riceGrowth = ((ricePrice - _priceHistory.first['rice']) / _priceHistory.first['rice'] * 100);
              final isPositive = riceGrowth >= 0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['year']}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        Text(
                          'Rice • Rs. $ricePrice',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isPositive ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                              color: isPositive ? Colors.green : Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${riceGrowth.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isPositive ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'W:$wheatPrice C:$cornPrice',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
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
    return Expanded(
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
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                color: isPositive ? Colors.green : Colors.red,
                size: 11,
              ),
              const SizedBox(width: 2),
              Text(
                change,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}