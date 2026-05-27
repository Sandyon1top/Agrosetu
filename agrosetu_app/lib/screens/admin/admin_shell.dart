import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_translations.dart';
import '../../services/api_service.dart';
import '../../services/user_service.dart';
import '../login_screen.dart';
import 'admin_dashboard_page.dart';
import 'admin_detections_page.dart';
import 'admin_posts_page.dart';
import 'admin_users_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _shellColors = _ShellColors();

  @override
  Widget build(BuildContext context) {
    final pages = const [
      AdminDashboardPage(),
      AdminUsersPage(),
      AdminPostsPage(),
      AdminDetectionsPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _shellColors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'admin.status_admin'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _titleFor(_index),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'auth.logout'.tr,
            icon: const Icon(Iconsax.logout, color: Colors.black87),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedItemColor: _shellColors.green,
          unselectedItemColor: Colors.grey.shade500,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.activity),
              label: 'admin.dashboard'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.people),
              label: 'admin.users'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.message),
              label: 'admin.posts'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Iconsax.health),
              label: 'admin.detections'.tr,
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(int i) {
    switch (i) {
      case 1:
        return 'admin.users'.tr;
      case 2:
        return 'admin.posts'.tr;
      case 3:
        return 'admin.detections'.tr;
      default:
        return 'admin.dashboard'.tr;
    }
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.logout'.tr,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'auth.logout_confirm'.tr,
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
              'auth.logout'.tr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await UserService.logout();
    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('is_logged_in');
    await prefs.remove('is_admin_session');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _ShellColors {
  const _ShellColors();
  final green = const Color(0xFF1B5E20);
}
