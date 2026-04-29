import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  // ─── Data ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _commodityData = [];
  List<String> _commodities = [];
  String _selectedCrop = '';
  bool _isLoading = true;

  // ─── Tab Navigation ───────────────────────────────────────────────────────
  int _activeTab = 0;
  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.bar_chart_rounded,     'label': 'Season'},
    {'icon': Icons.device_thermostat,     'label': 'Climate'},
    {'icon': Icons.show_chart_rounded,    'label': 'Risk'},
    {'icon': Icons.agriculture,           'label': 'Plant'},
    {'icon': Icons.auto_graph_rounded,    'label': 'Forecast'},
  ];

  // ─── Search ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  // Filtered list based on search query
  List<String> get _filteredCommodities {
    if (_searchQuery.isEmpty) return _commodities;
    return _commodities
        .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // Search result highlighted commodities (for the dropdown overlay)
  List<Map<String, dynamic>> get _filteredCommodityData {
    if (_searchQuery.isEmpty) return _commodityData;
    return _commodityData
        .where((d) => (d['commodity'] as String)
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ─── Seasonal Data (computed from CSV) ───────────────────────────────────
  // Map<cropName, Map<seasonName, avgPrice>>
  Map<String, Map<String, double>> _seasonalPrices = {};
  // Map<cropName, peakMonthName>
  Map<String, String> _peakMonthMap = {};
  // Map<cropName, suggestedPlantMonth>
  Map<String, String> _plantMonthMap = {};

  // ─── Climate Data ─────────────────────────────────────────────────────────
  // Map<month(1-12), avgRainfall>
  Map<int, double> _monthlyRainfall = {};
  // Map<month(1-12), avgTemp>
  Map<int, double> _monthlyTemp = {};

  // ─── Monthly Price Data (for correlation chart) ───────────────────────────
  // Map<cropName, Map<month(1-12), avgPrice>>
  final Map<String, Map<int, double>> _monthlyPrices = {};

  // ─── Volatility Data (Feature 4) ─────────────────────────────────────────
  // Map<cropName, {stdDev, cv, riskLevel, avgPrice}>
  final Map<String, Map<String, dynamic>> _volatilityData = {};

  // Nepal seasons by calendar month number
  static const Map<int, String> _monthToSeason = {
    1: 'Winter',  2: 'Winter',
    3: 'Pre-Monsoon', 4: 'Pre-Monsoon', 5: 'Pre-Monsoon',
    6: 'Monsoon', 7: 'Monsoon', 8: 'Monsoon', 9: 'Monsoon',
    10: 'Post-Monsoon', 11: 'Post-Monsoon',
    12: 'Winter',
  };

  static const List<String> _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // Season colours for UI
  static const Map<String, Color> _seasonColors = {
    'Winter':       Color(0xFF1565C0),
    'Pre-Monsoon':  Color(0xFFF57F17),
    'Monsoon':      Color(0xFF2E7D32),
    'Post-Monsoon': Color(0xFF6A1B9A),
  };

  static const Map<String, IconData> _seasonIcons = {
    'Winter':       Icons.ac_unit,
    'Pre-Monsoon':  Icons.wb_sunny,
    'Monsoon':      Icons.umbrella,
    'Post-Monsoon': Icons.cloud,
  };

  @override
  void initState() {
    super.initState();
    ActivityService.addActivity('market', 'Viewed strategic market analytics');
    _clearCacheAndLoad(); // clears stale cache on each dev reload

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _isSearching = _searchQuery.isNotEmpty;
      });
    });

    // Hide dropdown when focus is lost
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── Clear stale cache & reload ──────────────────────────────────────────
  Future<void> _clearCacheAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('commodity_data_cache');
    await prefs.remove('seasonal_data_cache');
    await prefs.remove('peak_month_cache');
    await prefs.remove('plant_month_cache');
    await prefs.remove('climate_cache');
    _loadClimateData(); // load climate in parallel
    _loadCsvData();
  }

  // ─── Climate Data Loading ──────────────────────────────────────────────────
  Future<void> _loadClimateData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('climate_cache');

      if (cached != null) {
        try {
          final decoded = jsonDecode(cached) as Map<String, dynamic>;
          final rainfall = (decoded['rainfall'] as Map).map<int, double>(
              (k, v) => MapEntry(int.parse(k.toString()), (v as num).toDouble()));
          final temp = (decoded['temp'] as Map).map<int, double>(
              (k, v) => MapEntry(int.parse(k.toString()), (v as num).toDouble()));
          if (mounted) {
            setState(() {
              _monthlyRainfall = rainfall;
              _monthlyTemp = temp;
            });
          }
          return;
        } catch (e) {
          debugPrint('🌦️ Climate cache corrupted, refetching: $e');
          await prefs.remove('climate_cache');
        }
      }

      // Pre-aggregated monthly averages (12 entries × 2 series, ~700 bytes).
      // Source CSV (111 MB) was OOM-killing the app on iPhone 11; we now ship
      // the rolled-up monthly data instead. Regenerate with the Python snippet
      // in the repo notes if Nepal_Climate_Data.csv is updated.
      final jsonStr = await rootBundle.loadString('data/climate_monthly.json');
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rainfall = (decoded['rainfall'] as Map).map<int, double>(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()));
      final temp = (decoded['temp'] as Map).map<int, double>(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()));

      await prefs.setString('climate_cache', jsonEncode({
        'rainfall': rainfall.map((k, v) => MapEntry(k.toString(), v)),
        'temp':     temp.map((k, v) => MapEntry(k.toString(), v)),
      }));

      setState(() {
        _monthlyRainfall = rainfall;
        _monthlyTemp = temp;
      });
    } catch (e, stack) {
      debugPrint('🌦️ Climate load error: $e');
      debugPrint(stack.toString());
      // Climate data is supplementary — fail silently in production
    }
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────
  Future<void> _loadCsvData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ── Try aggregate cache ──────────────────────────────────────────────
      final cachedData = prefs.getString('commodity_data_cache');
      final cachedSeasonal = prefs.getString('seasonal_data_cache');

      if (cachedData != null && cachedSeasonal != null) {
        final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
        final data = (decoded['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final commodities = List<String>.from(decoded['commodities'] as List);

        final decodedSeasonal = jsonDecode(cachedSeasonal) as Map<String, dynamic>;
        final seasonalPrices = decodedSeasonal.map((crop, seasons) =>
            MapEntry(crop, (seasons as Map<String, dynamic>).map(
                (s, v) => MapEntry(s, (v as num).toDouble()))));
        final peakMap = Map<String, String>.from(
            jsonDecode(prefs.getString('peak_month_cache') ?? '{}'));
        final plantMap = Map<String, String>.from(
            jsonDecode(prefs.getString('plant_month_cache') ?? '{}'));

        setState(() {
          _commodityData = data;
          _commodities = commodities;
          _selectedCrop = commodities.isNotEmpty ? commodities[0] : '';
          _seasonalPrices = seasonalPrices;
          _peakMonthMap = peakMap;
          _plantMonthMap = plantMap;
          _isLoading = false;
        });
        return;
      }

      // ── Parse CSV raw rows ───────────────────────────────────────────────
      final csvContent =
          await rootBundle.loadString('data/Kalimati_Tarkari_Dataset.csv');
      final lines = csvContent.split('\n');

      // commodity → list of {min, max, avg, month}
      final Map<String, List<Map<String, dynamic>>> rawRecords = {};

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 6) continue;

        final commodity = parts[0].trim();
        final dateStr   = parts[1].trim(); // e.g. 6/16/2013
        final minimum   = double.tryParse(parts[3].trim()) ?? 0;
        final maximum   = double.tryParse(parts[4].trim()) ?? 0;
        final average   = double.tryParse(parts[5].trim()) ?? 0;

        // Parse month from date (M/D/YYYY or YYYY-MM-DD)
        int month = 0;
        if (dateStr.contains('/')) {
          month = int.tryParse(dateStr.split('/')[0]) ?? 0;
        } else if (dateStr.contains('-')) {
          month = int.tryParse(dateStr.split('-')[1]) ?? 0;
        }

        rawRecords.putIfAbsent(commodity, () => []);
        rawRecords[commodity]!.add({
          'min': minimum,
          'max': maximum,
          'avg': average,
          'month': month,
        });
      }

      // ── Aggregate overall stats ──────────────────────────────────────────
      final List<Map<String, dynamic>> aggregatedData = [];
      final List<String> names = rawRecords.keys.toList()..sort();

      // ── Compute seasonal & peak data ─────────────────────────────────────
      final Map<String, Map<String, double>> seasonalPrices = {};
      final Map<String, String> peakMonthMap = {};
      final Map<String, String> plantMonthMap = {};

      for (final name in names) {
        final recs = rawRecords[name]!;

        // Overall aggregation
        final avgMin = recs.map((e) => e['min'] as double).reduce((a, b) => a + b) / recs.length;
        final avgMax = recs.map((e) => e['max'] as double).reduce((a, b) => a + b) / recs.length;
        final avgAvg = recs.map((e) => e['avg'] as double).reduce((a, b) => a + b) / recs.length;
        aggregatedData.add({
          'commodity': name,
          'minimum': avgMin,
          'maximum': avgMax,
          'average': avgAvg,
        });

        // Seasonal average prices
        final Map<String, List<double>> seasonBuckets = {
          'Winter': [], 'Pre-Monsoon': [], 'Monsoon': [], 'Post-Monsoon': []
        };
        // Monthly average prices (for peak detection)
        final Map<int, List<double>> monthBuckets = {};

        for (final rec in recs) {
          final m = rec['month'] as int;
          final avg = rec['avg'] as double;
          if (m < 1 || m > 12) continue;

          final season = _monthToSeason[m]!;
          seasonBuckets[season]!.add(avg);

          monthBuckets.putIfAbsent(m, () => []);
          monthBuckets[m]!.add(avg);
        }

        // Compute season averages
        seasonalPrices[name] = {};
        seasonBuckets.forEach((season, vals) {
          if (vals.isNotEmpty) {
            seasonalPrices[name]![season] =
                vals.reduce((a, b) => a + b) / vals.length;
          }
        });

        // Find peak month
        int peakMonth = 1;
        double peakPrice = 0;
        monthBuckets.forEach((m, vals) {
          final avg = vals.reduce((a, b) => a + b) / vals.length;
          if (avg > peakPrice) {
            peakPrice = avg;
            peakMonth = m;
          }
        });
        peakMonthMap[name] = _monthNames[peakMonth];

        // Suggest planting month = 3 months before peak (approx grow cycle)
        final plantMonthIndex = ((peakMonth - 4) % 12) + 1;
        plantMonthMap[name] = _monthNames[plantMonthIndex < 1 ? plantMonthIndex + 12 : plantMonthIndex];

        // Store monthly average prices for correlation chart
        final Map<int, double> monthlyAvg = {};
        monthBuckets.forEach((m, vals) {
          monthlyAvg[m] = vals.reduce((a, b) => a + b) / vals.length;
        });
        _monthlyPrices[name] = monthlyAvg;

        // ── Volatility computation ──────────────────────────────────────
        // Use all daily average prices to compute std deviation & CV
        final allPrices = recs.map((e) => e['avg'] as double).toList();
        final mean = allPrices.reduce((a, b) => a + b) / allPrices.length;
        final variance = allPrices
            .map((p) => (p - mean) * (p - mean))
            .reduce((a, b) => a + b) / allPrices.length;
        final stdDev = variance > 0 ? variance / mean : 0.0; // using variance/mean as proxy
        // Coefficient of Variation = stdDev / mean * 100
        final cv = mean > 0 ? (stdDev / mean) * 100 : 0.0;

        // Risk classification
        String riskLevel;
        if (cv < 15) {
          riskLevel = 'Low';
        } else if (cv < 35) {
          riskLevel = 'Medium';
        } else {
          riskLevel = 'High';
        }

        _volatilityData[name] = {
          'stdDev': stdDev,
          'cv': cv,
          'riskLevel': riskLevel,
          'avgPrice': mean,
          'minPrice': allPrices.reduce((a, b) => a < b ? a : b),
          'maxPrice': allPrices.reduce((a, b) => a > b ? a : b),
        };
      }

      // ── Cache everything ──────────────────────────────────────────────────
      await prefs.setString('commodity_data_cache',
          jsonEncode({'data': aggregatedData, 'commodities': names}));
      await prefs.setString('seasonal_data_cache', jsonEncode(seasonalPrices));
      await prefs.setString('peak_month_cache', jsonEncode(peakMonthMap));
      await prefs.setString('plant_month_cache', jsonEncode(plantMonthMap));

      setState(() {
        _commodityData = aggregatedData;
        _commodities = names;
        _selectedCrop = names.isNotEmpty ? names[0] : '';
        _seasonalPrices = seasonalPrices;
        _peakMonthMap = peakMonthMap;
        _plantMonthMap = plantMonthMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ─── Select a crop from search result ────────────────────────────────────
  void _selectCrop(String crop) {
    setState(() {
      _selectedCrop = crop;
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  // ─── Highlight matching text in search results ────────────────────────────
  Widget _highlightText(String text, String query) {
    if (query.isEmpty) return Text(text, style: GoogleFonts.poppins(fontSize: 13));

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) return Text(text, style: GoogleFonts.poppins(fontSize: 13));

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
        children: [
          TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + query.length),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
              backgroundColor: Color(0xFFE8F5E9),
            ),
          ),
          TextSpan(text: text.substring(matchIndex + query.length)),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text('Analysing 10 years of market data...',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            _searchFocusNode.unfocus();
            setState(() => _isSearching = false);
          },
          child: Stack(
            children: [
              Column(
                children: [
                  // ── Top section: header + search + chips ─────────────────
                  _buildCompactHeader(),

                  // ── Tab bar ───────────────────────────────────────────────
                  _buildTabBar(),

                  // ── Tab content ───────────────────────────────────────────
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: SingleChildScrollView(
                        key: ValueKey(_activeTab),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _buildActiveTabContent(),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Search dropdown overlay ───────────────────────────────────
              if (_isSearching)
                Positioned(
                  top: 148,
                  left: 16,
                  right: 16,
                  child: _buildSearchDropdownInner(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Compact Header (search + chips always visible) ───────────────────────
  Widget _buildCompactHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Market Advisor',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(_selectedCrop.isNotEmpty
                            ? 'Viewing: $_selectedCrop'
                            : 'Select a crop to begin',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search crop...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.white54),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.white60, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.white60),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Crop chips
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: (_searchQuery.isEmpty
                      ? _commodities
                      : _filteredCommodities)
                  .length,
              itemBuilder: (context, i) {
                final list = _searchQuery.isEmpty
                    ? _commodities
                    : _filteredCommodities;
                final crop = list[i];
                final isSelected = _selectedCrop == crop;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _selectCrop(crop),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        crop,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF1B5E20)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final isActive = _activeTab == i;
          final tab = _tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? const Color(0xFF2E7D32)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 18,
                      color: isActive
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isActive
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Active Tab Content ───────────────────────────────────────────────────
  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0: return _buildSeasonalCard();
      case 1: return _buildClimateCorrelationCard();
      case 2: return _buildVolatilityCard();
      case 3: return _buildPlantingRecommendation();
      case 4: return _buildPriceForecast();
      default: return _buildSeasonalCard();
    }
  }

  // ─── Search Dropdown (inner — used in new overlay positioning) ────────────
  Widget _buildSearchDropdownInner() {
    final results = _filteredCommodityData;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: results.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Icon(Icons.search_off, color: Colors.grey, size: 20),
                  const SizedBox(width: 10),
                  Text('No crops found for "$_searchQuery"',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey)),
                ]),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(children: [
                      Text('${results.length} results',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final cropName = item['commodity'] as String;
                        final isSelected = cropName == _selectedCrop;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E7D32)
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.eco,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF2E7D32)),
                          ),
                          title: _highlightText(cropName, _searchQuery),
                          trailing: Text(
                            'Rs.${(item['average'] as double).toInt()}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2E7D32)),
                          ),
                          onTap: () => _selectCrop(cropName),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Search Bar Widget ────────────────────────────────────────────────────
  // ─── Seasonal Price Pattern Card (data-driven) ───────────────────────────
  Widget _buildSeasonalCard() {
    final seasons = _seasonalPrices[_selectedCrop] ?? {};
    final peakMonth = _peakMonthMap[_selectedCrop] ?? '—';
    final plantMonth = _plantMonthMap[_selectedCrop] ?? '—';

    // Find best & worst season (only among seasons that have real data)
    String bestSeason = '—';
    String worstSeason = '—';
    double bestPrice = 0;
    double worstPrice = double.infinity;

    seasons.forEach((season, price) {
      if (price <= 0) return; // skip seasons with no data
      if (price > bestPrice) { bestPrice = price; bestSeason = season; }
      if (price < worstPrice) { worstPrice = price; worstSeason = season; }
    });

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 8),
              Text('Seasonal Price Pattern',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Based on 10 years of Kalimati market data',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          const Divider(height: 24),

          // ── Season Bars ────────────────────────────────────────────────
          if (seasons.isEmpty)
            Center(
              child: Text('No seasonal data available',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
            )
          else
            ...['Winter', 'Pre-Monsoon', 'Monsoon', 'Post-Monsoon'].map((season) {
              final price = seasons[season];
              // Skip seasons with no real data
              if (price == null || price <= 0) return const SizedBox.shrink();

              // Normalize bar width relative to best season
              final barFraction = bestPrice > 0 ? price / bestPrice : 0.0;
              final isBest = season == bestSeason;
              final color = _seasonColors[season] ?? Colors.grey;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_seasonIcons[season], size: 14, color: color),
                        const SizedBox(width: 6),
                        Text(season,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                                color: isBest ? color : Colors.black87)),
                        const Spacer(),
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('BEST SELL',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        const SizedBox(width: 8),
                        Text('Rs.${price.toInt()}/kg',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: barFraction.toDouble(),
                        minHeight: 10,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const Divider(height: 24),

          // ── Key Insights Row ───────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _insightChip(
                Icons.trending_up, 'Peak Month', peakMonth, Colors.orange.shade700)),
              const SizedBox(width: 10),
              Expanded(child: _insightChip(
                Icons.eco_outlined, 'Plant In', plantMonth, const Color(0xFF2E7D32))),
            ],
          ),
          const SizedBox(height: 10),

          // ── Avoid selling tip ──────────────────────────────────────────
          if (worstSeason != '—' && worstSeason != bestSeason && worstPrice < double.infinity)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avoid selling in $worstSeason — prices average Rs.${worstPrice.toInt()}/kg',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _insightChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  // ─── Climate vs Price Correlation Card (Feature 3) ───────────────────────
  Widget _buildClimateCorrelationCard() {
    final cropPrices = _monthlyPrices[_selectedCrop] ?? {};
    final hasClimate = _monthlyRainfall.isNotEmpty && _monthlyTemp.isNotEmpty;
    final hasPrices  = cropPrices.isNotEmpty;

    if (!hasClimate || !hasPrices) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off, color: Colors.grey),
          const SizedBox(width: 10),
          Text('Climate data not available',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
        ]),
      );
    }

    // Build 12 months of combined data
    final months = List.generate(12, (i) => i + 1);
    final prices    = months.map((m) => cropPrices[m] ?? 0.0).toList();
    final rainfall  = months.map((m) => _monthlyRainfall[m] ?? 0.0).toList();
    final temps     = months.map((m) => _monthlyTemp[m] ?? 0.0).toList();

    // Normalise values to 0–100 for dual axis display
    final maxPrice   = prices.reduce((a, b) => a > b ? a : b);
    final maxRain    = rainfall.reduce((a, b) => a > b ? a : b);
    final maxTemp    = temps.reduce((a, b) => a > b ? a : b);

    // Compute simple correlation insight
    // Count months where high rain aligns with low price
    int rainLowPriceCount = 0;
    int tempHighPriceCount = 0;
    for (int i = 0; i < 12; i++) {
      final normRain  = maxRain  > 0 ? rainfall[i] / maxRain  : 0;
      final normPrice = maxPrice > 0 ? prices[i]   / maxPrice : 0;
      final normTemp  = maxTemp  > 0 ? temps[i]    / maxTemp  : 0;
      if (normRain > 0.6 && normPrice < 0.5) rainLowPriceCount++;
      if (normTemp > 0.6 && normPrice > 0.5) tempHighPriceCount++;
    }
    final rainCorrelation = rainLowPriceCount >= 2
        ? '🌧️ Heavy rain months tend to lower prices (oversupply)'
        : '🌧️ Rainfall has little direct effect on price';
    final tempCorrelation = tempHighPriceCount >= 3
        ? '🌡️ Warmer months tend to push prices higher'
        : '🌡️ Temperature has a moderate effect on price';

    // Toggle state for rainfall vs temperature view
    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool showRainfall = true;

        return StatefulBuilder(
          builder: (context, setToggle) {
            final climateData = showRainfall ? rainfall : temps;
            final maxClimate  = showRainfall ? maxRain  : maxTemp;
            final climateLabel = showRainfall ? 'Rainfall (mm)' : 'Temp (°C)';
            final climateColor = showRainfall
                ? const Color(0xFF1565C0)
                : const Color(0xFFE65100);

            return Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ───────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.device_thermostat,
                          color: Color(0xFF1565C0), size: 22),
                      const SizedBox(width: 8),
                      Text('Climate vs Price',
                          style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900)),
                      const Spacer(),
                      // Toggle button
                      GestureDetector(
                        onTap: () => setToggle(() => showRainfall = !showRainfall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: climateColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: climateColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                showRainfall
                                    ? Icons.umbrella
                                    : Icons.thermostat,
                                size: 14,
                                color: climateColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                showRainfall ? 'Rain' : 'Temp',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: climateColor),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.swap_horiz,
                                  size: 12, color: climateColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('How $climateLabel affects $_selectedCrop price',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  // ── Legend ───────────────────────────────────────────────
                  Row(
                    children: [
                      _legendDot(const Color(0xFF2E7D32), 'Price (Rs/kg)'),
                      const SizedBox(width: 16),
                      _legendDot(climateColor, climateLabel),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Chart ────────────────────────────────────────────────
                  SizedBox(
                    height: 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (i) {
                        final month = i + 1;
                        final normPrice   = maxPrice   > 0 ? prices[i]       / maxPrice   : 0.0;
                        final normClimate = maxClimate > 0 ? climateData[i]  / maxClimate : 0.0;
                        final isHighPrice = prices[i] == maxPrice;
                        final isHighClimate = climateData[i] == maxClimate;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Price bar
                                Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Container(
                                      height: (normPrice * 160).clamp(4, 160).toDouble(),
                                      decoration: BoxDecoration(
                                        color: isHighPrice
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFF2E7D32)
                                                .withValues(alpha: 0.35),
                                        borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(4)),
                                      ),
                                    ),
                                    // Climate overlay line marker
                                    Positioned(
                                      top: (160 - (normClimate * 160))
                                          .clamp(0, 156)
                                          .toDouble(),
                                      child: Container(
                                        width: double.infinity,
                                        height: 3,
                                        color: isHighClimate
                                            ? climateColor
                                            : climateColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Month label
                                Text(
                                  _monthNames[month].substring(0, 1),
                                  style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Month labels row (full)
                  Row(
                    children: List.generate(12, (i) => Expanded(
                      child: Text(
                        _monthNames[i + 1],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 8, color: Colors.grey.shade400),
                      ),
                    )),
                  ),

                  const Divider(height: 24),

                  // ── Insight pills ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(rainCorrelation,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.blue.shade800)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tempCorrelation,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.orange.shade800)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  // ─── Price Volatility Card (Feature 4) ───────────────────────────────────
  Widget _buildVolatilityCard() {
    final vol = _volatilityData[_selectedCrop];
    if (vol == null) return const SizedBox.shrink();

    final riskLevel  = vol['riskLevel'] as String;
    final cv         = vol['cv'] as double;
    final avgPrice   = vol['avgPrice'] as double;
    final minPrice   = vol['minPrice'] as double;
    final maxPrice   = vol['maxPrice'] as double;
    final priceSwing = maxPrice - minPrice;

    // Risk color + message
    final Color riskColor;
    final String riskMessage;
    final IconData riskIcon;
    switch (riskLevel) {
      case 'Low':
        riskColor   = const Color(0xFF2E7D32);
        riskMessage = 'Stable income crop — safe for small farmers';
        riskIcon    = Icons.verified_rounded;
        break;
      case 'Medium':
        riskColor   = const Color(0xFFF57F17);
        riskMessage = 'Moderate price swings — plan harvest timing carefully';
        riskIcon    = Icons.warning_amber_rounded;
        break;
      default:
        riskColor   = const Color(0xFFC62828);
        riskMessage = 'High volatility — prices fluctuate heavily, risky to grow';
        riskIcon    = Icons.crisis_alert_rounded;
    }

    // Build top 5 safest and riskiest crops from all data
    final sorted = _volatilityData.entries.toList()
      ..sort((a, b) =>
          (a.value['cv'] as double).compareTo(b.value['cv'] as double));
    final top5Safe   = sorted.take(5).toList();
    final top5Risky  = sorted.reversed.take(5).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: riskColor, size: 22),
              const SizedBox(width: 8),
              Text('Price Volatility',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const Spacer(),
              // Risk badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(riskIcon, size: 13, color: riskColor),
                    const SizedBox(width: 4),
                    Text('$riskLevel Risk',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: riskColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Based on 10 years of daily price data',
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          const Divider(height: 24),

          // ── Risk message ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(riskIcon, size: 16, color: riskColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(riskMessage,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: riskColor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Stats row ────────────────────────────────────────────────────
          Row(
            children: [
              _volStat('Avg Price', 'Rs.${avgPrice.toInt()}', Colors.black87),
              _volStat('Lowest', 'Rs.${minPrice.toInt()}', const Color(0xFF2E7D32)),
              _volStat('Highest', 'Rs.${maxPrice.toInt()}', const Color(0xFFC62828)),
              _volStat('Price Swing', 'Rs.${priceSwing.toInt()}', const Color(0xFFF57F17)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Volatility gauge bar ─────────────────────────────────────────
          Text('Volatility Score',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Stack(
            children: [
              // Background track with gradient zones
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 14,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2E7D32),
                        Color(0xFFF57F17),
                        Color(0xFFC62828),
                      ],
                    ),
                  ),
                ),
              ),
              // Marker
              Positioned(
                left: ((cv.clamp(0, 60) / 60) *
                        (MediaQuery.of(context).size.width - 80))
                    .clamp(0,
                        MediaQuery.of(context).size.width - 100),
                top: -3,
                child: Icon(Icons.arrow_drop_down,
                    size: 20, color: Colors.black87),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stable',
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: const Color(0xFF2E7D32))),
                Text('Moderate',
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: const Color(0xFFF57F17))),
                Text('Volatile',
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: const Color(0xFFC62828))),
              ],
            ),
          ),
          const Divider(height: 28),

          // ── Top 5 Safest Crops ───────────────────────────────────────────
          Text('✅  5 Most Stable Crops to Grow',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32))),
          const SizedBox(height: 10),
          ...top5Safe.map((e) => _volatilityRow(
              e.key,
              e.value['riskLevel'] as String,
              e.value['cv'] as double,
              e.value['avgPrice'] as double,
              isSelected: e.key == _selectedCrop)),

          const SizedBox(height: 16),

          // ── Top 5 Riskiest Crops ─────────────────────────────────────────
          Text('⚠️  5 Most Volatile Crops',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC62828))),
          const SizedBox(height: 10),
          ...top5Risky.map((e) => _volatilityRow(
              e.key,
              e.value['riskLevel'] as String,
              e.value['cv'] as double,
              e.value['avgPrice'] as double,
              isSelected: e.key == _selectedCrop)),
        ],
      ),
    );
  }

  Widget _volStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _volatilityRow(
      String cropName, String risk, double cv, double avg,
      {bool isSelected = false}) {
    final Color color = risk == 'Low'
        ? const Color(0xFF2E7D32)
        : risk == 'Medium'
            ? const Color(0xFFF57F17)
            : const Color(0xFFC62828);

    return GestureDetector(
      onTap: () => _selectCrop(cropName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                cropName,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('Rs.${avg.toInt()}/kg',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(risk,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Price Trends Chart ───────────────────────────────────────────────────
  // ─── Feature 5: Planting Recommendation ──────────────────────────────────
  Widget _buildPlantingRecommendation() {
    final peakMonth  = _peakMonthMap[_selectedCrop] ?? '—';
    final plantMonth = _plantMonthMap[_selectedCrop] ?? '—';
    final seasons    = _seasonalPrices[_selectedCrop] ?? {};
    final vol        = _volatilityData[_selectedCrop];
    final riskLevel  = vol?['riskLevel'] as String? ?? 'Medium';

    // Best season to sell
    String bestSeason = '—';
    double bestPrice  = 0;
    seasons.forEach((s, p) {
      if (p > bestPrice) { bestPrice = p; bestSeason = s; }
    });

    // Grow cycle estimate based on risk/season
    final Map<String, int> growDays = {
      'Winter': 90, 'Pre-Monsoon': 75, 'Monsoon': 60, 'Post-Monsoon': 80
    };
    final days = growDays[bestSeason] ?? 80;

    // Steps
    final steps = [
      {'icon': Icons.eco_outlined,       'color': const Color(0xFF2E7D32),
       'title': 'Start Planting',        'value': plantMonth},
      {'icon': Icons.water_drop_outlined,'color': const Color(0xFF1565C0),
       'title': 'Grow Period',           'value': '~$days days'},
      {'icon': Icons.agriculture,        'color': const Color(0xFFF57F17),
       'title': 'Harvest Ready',         'value': peakMonth},
      {'icon': Icons.sell_outlined,      'color': const Color(0xFF6A1B9A),
       'title': 'Best Season to Sell',   'value': bestSeason},
      {'icon': Icons.payments_outlined,  'color': const Color(0xFF2E7D32),
       'title': 'Expected Price',        'value': 'Rs.${bestPrice.toInt()}/kg'},
    ];

    final Color riskColor = riskLevel == 'Low'
        ? const Color(0xFF2E7D32)
        : riskLevel == 'Medium'
            ? const Color(0xFFF57F17)
            : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.agriculture, color: Color(0xFF2E7D32), size: 22),
            const SizedBox(width: 8),
            Text('Planting Roadmap',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$riskLevel Risk',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: riskColor)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Step-by-step guide for max profit',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
          const Divider(height: 24),

          // Timeline steps
          ...List.generate(steps.length, (i) {
            final step  = steps[i];
            final color = step['color'] as Color;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dot + line
                Column(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(step['icon'] as IconData,
                        size: 18, color: color),
                  ),
                  if (!isLast)
                    Container(
                        width: 2, height: 28,
                        color: Colors.grey.shade200),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 28),
                    child: Row(
                      children: [
                        Text(step['title'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                        const Spacer(),
                        Text(step['value'] as String,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Feature 6: Price Forecasting ────────────────────────────────────────
  Widget _buildPriceForecast() {
    final monthlyPrices = _monthlyPrices[_selectedCrop];
    if (monthlyPrices == null || monthlyPrices.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build year-over-year average using all data
    // We'll use monthly averages as 12 data points and project 6 months ahead
    // using simple linear regression on monthly index
    final List<double> prices = List.generate(
        12, (i) => monthlyPrices[i + 1] ?? 0);

    // Only use months with data
    final validIndices = <int>[];
    final validPrices  = <double>[];
    for (int i = 0; i < 12; i++) {
      if (prices[i] > 0) {
        validIndices.add(i);
        validPrices.add(prices[i]);
      }
    }
    if (validPrices.isEmpty) return const SizedBox.shrink();

    // Simple linear regression: y = a + b*x
    final n    = validIndices.length.toDouble();
    final sumX = validIndices.fold(0.0, (s, x) => s + x);
    final sumY = validPrices.fold(0.0, (s, y) => s + y);
    final sumXY = List.generate(validIndices.length,
            (i) => validIndices[i] * validPrices[i])
        .fold(0.0, (s, v) => s + v);
    final sumX2 = validIndices
        .fold(0.0, (s, x) => s + x * x);
    final b = (n * sumXY - sumX * sumY) /
        ((n * sumX2 - sumX * sumX).abs() < 0.001
            ? 0.001
            : n * sumX2 - sumX * sumX);
    final a = (sumY - b * sumX) / n;

    // Project 6 months ahead (indices 12–17)
    final forecastPrices = List.generate(
        6, (i) => (a + b * (12 + i)).clamp(0, double.infinity));

    // Current month (0-based)
    final now        = DateTime.now();
    final startMonth = now.month; // 1-based

    // Trend direction
    final trend     = b > 1 ? 'rising' : b < -1 ? 'falling' : 'stable';
    final trendIcon = b > 1 ? Icons.trending_up : b < -1
        ? Icons.trending_down : Icons.trending_flat;
    final trendColor = b > 1 ? const Color(0xFF2E7D32)
        : b < -1 ? const Color(0xFFC62828) : const Color(0xFFF57F17);

    final maxForecast = forecastPrices.reduce((a, b) => a > b ? a : b);
    final bestForecastMonth = forecastPrices.indexOf(maxForecast);
    final bestMonthName = _monthNames[
        ((startMonth + bestForecastMonth - 1) % 12) + 1];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────────
          Row(children: [
            Icon(trendIcon, color: trendColor, size: 22),
            const SizedBox(width: 8),
            Text('Price Forecast',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trendIcon, size: 12, color: trendColor),
                const SizedBox(width: 4),
                Text(trend.toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: trendColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Next 6 months projection (linear trend)',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade500)),
          const Divider(height: 24),

          // ── Forecast bars ───────────────────────────────────────────────
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(6, (i) {
                final price     = forecastPrices[i];
                final normH     = maxForecast > 0 ? price / maxForecast : 0.0;
                final monthIdx  = ((startMonth + i - 1) % 12) + 1;
                final monthName = _monthNames[monthIdx];
                final isBest    = i == bestForecastMonth;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Price label on top of bar
                        Text('${price.toInt()}',
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: isBest
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isBest
                                    ? Colors.purple.shade700
                                    : Colors.grey.shade500)),
                        const SizedBox(height: 3),
                        Container(
                          height: (normH * 100).clamp(8, 100).toDouble(),
                          decoration: BoxDecoration(
                            color: isBest
                                ? Colors.purple.shade400
                                : Colors.purple.shade100,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(monthName,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: isBest
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isBest
                                    ? Colors.purple.shade700
                                    : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 24),

          // ── Insight ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline,
                  color: Colors.purple.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Best month to sell in next 6 months: $bestMonthName '
                  '(projected Rs.${maxForecast.toInt()}/kg). '
                  'Price trend is $trend.',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.purple.shade800),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 10),
          // Disclaimer
          Text(
            '⚠️ Forecast is based on historical seasonal patterns. '
            'Actual prices may vary.',
            style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}