import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../l10n/app_translations.dart';
import '../../services/api_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const _green = Color(0xFF1B5E20);

  List<Map<String, dynamic>> _users = [];
  int _page = 1;
  int _total = 0;
  final int _limit = 20;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.adminGetUsers(
      page: _page,
      limit: _limit,
      search: _searchCtrl.text.trim(),
    );
    if (!mounted) return;
    if (res['status'] != 'ok') {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Failed to load users';
      });
      return;
    }
    setState(() {
      _users = List<Map<String, dynamic>>.from(res['users'] ?? []);
      _total = (res['total'] ?? 0) as int;
      _loading = false;
    });
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  Future<bool> _confirm(String title, String body, String okLabel,
      {Color okColor = Colors.red}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(body, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('auth.cancel'.tr,
                style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: okColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              okLabel,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _suspend(Map<String, dynamic> u) async {
    final ok = await _confirm(
      'admin.confirm_suspend_title'.tr,
      'admin.confirm_suspend_body'.tr,
      'admin.action_suspend'.tr,
      okColor: Colors.orange.shade700,
    );
    if (!ok) return;
    final r = await ApiService.adminSuspendUser(u['id'].toString());
    _toast(r['status'] == 'ok'
        ? 'admin.user_suspended'.tr
        : (r['message']?.toString() ?? 'admin.failed'.tr));
    if (r['status'] == 'ok') _load();
  }

  Future<void> _activate(Map<String, dynamic> u) async {
    final r = await ApiService.adminActivateUser(u['id'].toString());
    _toast(r['status'] == 'ok'
        ? 'admin.user_activated'.tr
        : (r['message']?.toString() ?? 'admin.failed'.tr));
    if (r['status'] == 'ok') _load();
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final ok = await _confirm(
      'admin.confirm_delete_user_title'.tr,
      'admin.confirm_delete_user_body'.tr,
      'admin.confirm_delete_forever'.tr,
    );
    if (!ok) return;
    final r = await ApiService.adminDeleteUser(u['id'].toString());
    _toast(r['status'] == 'ok'
        ? 'admin.user_deleted'.tr
        : (r['message']?.toString() ?? 'admin.failed'.tr));
    if (r['status'] == 'ok') _load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = (_total == 0) ? 1 : ((_total + _limit - 1) ~/ _limit);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'admin.search_users'.tr,
              hintStyle: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade400),
              prefixIcon:
                  Icon(Iconsax.search_normal, size: 18, color: Colors.grey.shade500),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(child: _body()),
        if (!_loading && _error == null && _users.isNotEmpty)
          _pager(pages),
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
    if (_users.isEmpty) {
      return Center(
        child: Text(
          'admin.empty_users'.tr,
          style: GoogleFonts.poppins(color: Colors.grey.shade500),
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _userTile(_users[i]),
      ),
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    final active = u['isActive'] == true;
    final isAdmin = u['isAdmin'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u['name']?.toString() ?? '—',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          _badge('admin.status_admin'.tr, Colors.purple),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u['email']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _badge(
                active ? 'admin.status_active'.tr : 'admin.status_suspended'.tr,
                active ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat(Iconsax.message, '${u['postCount'] ?? 0}'),
              const SizedBox(width: 12),
              _miniStat(Iconsax.health, '${u['detectionCount'] ?? 0}'),
              const Spacer(),
              if (active)
                _actionBtn(
                  'admin.action_suspend'.tr,
                  Colors.orange.shade700,
                  () => _suspend(u),
                )
              else
                _actionBtn(
                  'admin.action_activate'.tr,
                  Colors.green.shade700,
                  () => _activate(u),
                ),
              const SizedBox(width: 6),
              _actionBtn(
                'admin.action_delete'.tr,
                Colors.red.shade700,
                () => _delete(u),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, MaterialColor color) {
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
          fontWeight: FontWeight.w700,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String v) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          v,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
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
              '${'admin.showing'.tr} ${_users.length} ${'admin.of'.tr} $_total',
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
