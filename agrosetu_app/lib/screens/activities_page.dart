import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/activity_service.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ActivityService.getAllActivities();
    all.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    setState(() => _items = all);
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today, ${TimeOfDay.fromDateTime(dt).format(context)}';
    if (diff.inDays < 7) return '${diff.inDays} day(s) ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Activities', style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _items.isEmpty
            ? Center(child: Text('No activities yet', style: GoogleFonts.poppins()))
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, idx) {
                  final it = _items[idx];
                  return ListTile(
                    title: Text(it['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text(_formatTime(it['timestamp']), style: GoogleFonts.poppins(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  );
                },
              ),
      ),
    );
  }
}
