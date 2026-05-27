import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../l10n/app_translations.dart';
import '../../services/api_service.dart';

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

class _AdminPostsPageState extends State<AdminPostsPage> {
  static const _green = Color(0xFF1B5E20);

  List<Map<String, dynamic>> _posts = [];
  int _page = 1;
  int _total = 0;
  final int _limit = 15;
  bool _loading = true;
  String? _error;
  bool _reportedOnly = false;

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
    final r = await ApiService.adminGetPosts(page: _page, limit: _limit, reportedOnly: _reportedOnly);
    if (!mounted) return;
    if (r['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = r['message']?.toString() ?? 'Failed to load posts';
      });
      return;
    }
    setState(() {
      _posts = List<Map<String, dynamic>>.from(r['posts'] ?? []);
      _total = (r['total'] ?? 0) as int;
      _loading = false;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _togglePin(Map<String, dynamic> p) async {
    final wasPinned = p['pinned'] == true;
    final r = await ApiService.adminPinPost(p['id'].toString(), !wasPinned);
    _toast(r['status'] == 'ok'
        ? (wasPinned ? 'admin.post_unpinned'.tr : 'admin.post_pinned'.tr)
        : 'admin.failed'.tr);
    if (r['status'] == 'ok') _load();
  }

  Future<void> _clearReports(Map<String, dynamic> p) async {
    final r = await ApiService.adminClearReports(p['id'].toString());
    _toast(r['status'] == 'ok' ? 'admin.reports_cleared'.tr : 'admin.failed'.tr);
    if (r['status'] == 'ok') _load();
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.confirm_delete_post_title'.tr,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          '${'admin.confirm_delete_post_body'.tr}\n\n"${p['title'] ?? 'admin.no_title'.tr}"',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('auth.cancel'.tr,
                style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'admin.action_delete'.tr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiService.adminDeletePost(p['id'].toString());
    _toast(r['status'] == 'ok'
        ? 'admin.post_deleted'.tr
        : (r['message']?.toString() ?? 'admin.failed'.tr));
    if (r['status'] == 'ok') _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = (_total == 0) ? 1 : ((_total + _limit - 1) ~/ _limit);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              FilterChip(
                label: Text('🚨 Reported only',
                    style: GoogleFonts.poppins(fontSize: 12)),
                selected: _reportedOnly,
                selectedColor: Colors.red.shade50,
                checkmarkColor: Colors.red.shade700,
                onSelected: (v) {
                  setState(() {
                    _reportedOnly = v;
                    _page = 1;
                  });
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(child: _body()),
        if (!_loading && _error == null && _posts.isNotEmpty) _pager(pages),
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
    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'admin.empty_posts'.tr,
          style: GoogleFonts.poppins(color: Colors.grey.shade500),
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _postCard(_posts[i]),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final pinned = p['pinned'] == true;
    final solved = p['solved'] == true;
    final reportCount = (p['reportCount'] ?? 0) as int;
    final isReported = reportCount > 0;
    final author = p['author'] is Map ? Map<String, dynamic>.from(p['author']) : {};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: pinned
            ? Border.all(color: Colors.amber.shade400, width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((p['imageUrl']?.toString() ?? '').isNotEmpty)
                _thumb(p['imageUrl']?.toString() ?? ''),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (pinned)
                          _chip('📌 ${'admin.pinned_label'.tr}', Colors.amber),
                        if ((p['category'] ?? '').toString().isNotEmpty)
                          _chip(p['category'].toString(), Colors.grey),
                        if (solved)
                          _chip('admin.solved_label'.tr, Colors.green),
                        if (isReported)
                          _chip('🚨 Reported ($reportCount)', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (p['title']?.toString().isNotEmpty ?? false)
                          ? p['title']
                          : 'admin.no_title'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'by ${author['name'] ?? 'unknown'} · ❤️ ${p['likeCount'] ?? 0} · 💬 ${p['commentCount'] ?? 0}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              _btn(
                pinned ? 'admin.action_unpin'.tr : 'admin.action_pin'.tr,
                pinned ? Colors.grey.shade600 : Colors.amber.shade800,
                () => _togglePin(p),
              ),
              const SizedBox(width: 6),
              if (isReported) ...[
                _btn('Clear', Colors.orange.shade700, () => _clearReports(p)),
                const SizedBox(width: 6),
              ],
              _btn(
                'admin.action_delete'.tr,
                Colors.red.shade700,
                () => _delete(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thumb(String src) {
    Uint8List? bytes;
    try {
      final raw = src.startsWith('data:')
          ? src.substring(src.indexOf(',') + 1)
          : src;
      bytes = base64Decode(raw);
    } catch (_) {
      bytes = null;
    }
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Icon(Iconsax.image, color: Colors.grey.shade400, size: 22),
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
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
              '${'admin.showing'.tr} ${_posts.length} ${'admin.of'.tr} $_total',
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
