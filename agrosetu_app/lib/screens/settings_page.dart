import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/user_preferences_service.dart';
import '../services/user_service.dart';
import '../services/disease_history_service.dart';
import '../services/activity_service.dart';
import 'change_password_page.dart';
import 'language_selection_page.dart';
import 'location_services_page.dart';
import 'login_screen.dart';
import 'privacy_security_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserPreferences? _prefs;
  bool _isLoading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await UserPreferencesService.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _isLoading = false;
    });
  }

  Future<void> _openLanguage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
    );
    if (!mounted) return;
    _loadPrefs();
  }

  Future<void> _openLocation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationServicesPage()),
    );
    if (!mounted) return;
    _loadPrefs();
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
    );
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'settings.delete_account'.tr,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'settings.delete_warn'.tr,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'auth.cancel'.tr,
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'settings.delete_button'.tr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = await UserService.getUser();
    final userId = user?['id']?.toString();
    if (userId == null) {
      _toast('settings.not_signed_in'.tr);
      return;
    }

    setState(() => _deleting = true);
    final res = await ApiService.deactivateAccount(userId);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (res['status'] == 'ok') {
      await UserService.clearAll();
      await ApiService.logout();
      await NotificationService.clearAll();
      await DiseaseHistoryService.clearAll();
      await ActivityService.clearAll();
      await UserPreferencesService.clearCacheOnly();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      _toast(res['message']?.toString() ?? 'Failed to delete account');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'settings.title'.tr,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _prefs!;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('settings.section_app'.tr),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: Iconsax.language_circle,
                      title: 'settings.language'.tr,
                      subtitle: p.languageLabel,
                      onTap: _openLanguage,
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Iconsax.location,
                      title: 'settings.location_services'.tr,
                      subtitle: p.locationServicesEnabled
                          ? 'settings.on'.tr
                          : 'settings.off'.tr,
                      onTap: _openLocation,
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Iconsax.global,
                      title: 'settings.data_privacy'.tr,
                      subtitle: 'settings.manage_prefs'.tr,
                      onTap: _openPrivacy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('settings.section_account'.tr),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: Iconsax.user,
                      title: 'settings.change_password'.tr,
                      subtitle: 'settings.update_password'.tr,
                      onTap: _openChangePassword,
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Iconsax.trash,
                      title: 'settings.delete_account'.tr,
                      subtitle: 'settings.delete_subtitle'.tr,
                      titleColor: Colors.red,
                      onTap: _deleting ? null : _confirmDeleteAccount,
                      trailing: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2E7D32),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Iconsax.arrow_right_3,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
          ],
        ),
      ),
    );
  }
}
