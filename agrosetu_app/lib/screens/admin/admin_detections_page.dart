import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../l10n/app_translations.dart';
import '../../services/api_service.dart';

class AdminDetectionsPage extends StatefulWidget {
  const AdminDetectionsPage({super.key});

  @override
  State<AdminDetectionsPage> createState() => _AdminDetectionsPageState();
}

class _AdminDetectionsPageState extends State<AdminDetectionsPage> {
  static const _green = Color(0xFF1B5E20);

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _total = 0;
  final int _limit = 25;
  bool _loading = true;
  String? _error;

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
    final r = await ApiService.adminGetDetections(page: _page, limit: _limit);
    if (!mounted) return;
    if (r['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = r['message']?.toString() ?? 'Failed to load detections';
      });
      return;
    }
    setState(() {
      _items = List<Map<String, dynamic>>.from(r['detections'] ?? []);
      _total = (r['total'] ?? 0) as int;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = (_total == 0) ? 1 : ((_total + _limit - 1) ~/ _limit);
    return Column(
      children: [
        Expanded(child: _body()),
        if (!_loading && _error == null && _items.isNotEmpty) _pager(pages),
      ],
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'admin.empty_detections'.tr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _row(_items[i]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> d) {
    final user = d['user'] is Map ? Map<String, dynamic>.from(d['user']) : null;
    final confStr = (d['confidence'] ?? '').toString();
    final conf = double.tryParse(confStr.replaceAll('%', '').trim()) ?? 0.0;
    final confColor = conf >= 90
        ? Colors.green.shade700
        : conf >= 70
            ? Colors.blue.shade700
            : Colors.orange.shade700;

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Iconsax.health, color: confColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['disease']?.toString() ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user?['name'] ?? '—'} · ${_fmtDate(d['createdAt'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              confStr.isEmpty ? '—' : confStr,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: confColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        final hh = d.hour.toString().padLeft(2, '0');
        final mm = d.minute.toString().padLeft(2, '0');
        return 'today $hh:$mm';
      }
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _pager(int pages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${'admin.showing'.tr} ${_items.length} ${'admin.of'.tr} $_total',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.arrow_left_2, size: 18),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
          ),
          Text(
            '${'admin.page_of'.tr} $_page / $pages',
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Iconsax.arrow_right_3, size: 18),
            onPressed: _page < pages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
