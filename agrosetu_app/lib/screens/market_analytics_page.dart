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

  final List<Map<String, dynamic>> _priceData = [
    {
      'year': 2013,
      'rice': 25,
      'wheat': 20,
      'corn': 18,
    },
    {
      'year': 2014,
      'rice': 28,
      'wheat': 22,
      'corn': 19,
    },
    {
      'year': 2015,
      'rice': 30,
      'wheat': 24,
      'corn': 20,
    },
    {
      'year': 2016,
      'rice': 32,
      'wheat': 25,
      'corn': 21,
    },
    {
      'year': 2017,
      'rice': 35,
      'wheat': 26,
      'corn': 22,
    },
    {
      'year': 2018,
      'rice': 38,
      'wheat': 28,
      'corn': 24,
    },
    {
      'year': 2019,
      'rice': 40,
      'wheat': 30,
      'corn': 26,
    },
    {
      'year': 2020,
      'rice': 42,
      'wheat': 32,
      'corn': 28,
    },
    {
      'year': 2021,
      'rice': 45,
      'wheat': 34,
      'corn': 30,
    },
  ];

  double _getPriceForCrop(String crop) {
    final lastYearData = _priceData.last;
    switch (crop.toLowerCase()) {
      case 'rice':
        return lastYearData['rice'].toDouble();
      case 'wheat':
        return lastYearData['wheat'].toDouble();
      case 'corn':
        return lastYearData['corn'].toDouble();
      default:
        return 25.0;
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Analytics',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Historical crop price trends (2013-2021)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                title: 'Current Price',
                value: 'Rs. ${_getPriceForCrop(_selectedCrop).toInt()}',
                change: '+8.2%',
                isPositive: true,
              ),
              _StatItem(
                title: 'Avg Growth',
                value: '6.5%',
                change: 'per year',
                isPositive: true,
              ),
              _StatItem(
                title: 'Best Month',
                value: 'October',
                change: '+12%',
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _crops.map((crop) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(crop),
                selected: _selectedCrop == crop,
                onSelected: (selected) {
                  setState(() {
                    _selectedCrop = crop;
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF2E7D32).withOpacity(0.1),
                labelStyle: GoogleFonts.poppins(
                  color: _selectedCrop == crop ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                checkmarkColor: const Color(0xFF2E7D32),
                side: BorderSide(
                  color: _selectedCrop == crop ? const Color(0xFF2E7D32) : Colors.grey.shade300,
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
            'Historical Prices (Rs./kg)',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Year')),
                DataColumn(label: Text('Rice')),
                DataColumn(label: Text('Wheat')),
                DataColumn(label: Text('Corn')),
                DataColumn(label: Text('Change')),
              ],
              rows: _priceData.map((data) {
                final change = data['rice'] - _priceData.first['rice'];
                return DataRow(
                  cells: [
                    DataCell(Text(data['year'].toString())),
                    DataCell(Text('Rs. ${data['rice']}')),
                    DataCell(Text('Rs. ${data['wheat']}')),
                    DataCell(Text('Rs. ${data['corn']}')),
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            change >= 0 ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                            color: change >= 0 ? Colors.green : Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                            style: GoogleFonts.poppins(
                              color: change >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isPositive ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
              color: isPositive ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              change,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isPositive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}