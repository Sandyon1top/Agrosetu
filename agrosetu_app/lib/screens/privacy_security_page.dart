import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/user_preferences_service.dart';
import '../services/user_service.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _isLoading = true;
  bool _profileVisibility = true;
  bool _activityLogging = true;
  bool _exporting = false;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await UserPreferencesService.load();
    if (!mounted) return;
    setState(() {
      _profileVisibility = p.profileVisibility;
      _activityLogging = p.activityLogging;
      _isLoading = false;
    });
    UserPreferencesService.refreshFromBackend().then((p) {
      if (!mounted) return;
      setState(() {
        _profileVisibility = p.profileVisibility;
        _activityLogging = p.activityLogging;
      });
    });
  }

  Future<void> _setProfileVisibility(bool v) async {
    setState(() => _profileVisibility = v);
    await UserPreferencesService.update(profileVisibility: v);
  }

  Future<void> _setActivityLogging(bool v) async {
    setState(() => _activityLogging = v);
    await UserPreferencesService.update(activityLogging: v);
  }

  Future<void> _downloadData() async {
    final user = await UserService.getUser();
    final userId = user?['id']?.toString();
    if (userId == null) {
      _toast('privacy.signin_required'.tr);
      return;
    }
    setState(() => _exporting = true);
    final res = await ApiService.exportUserData(userId);
    if (!mounted) {
      return;
    }

    if (res['status'] != 'ok') {
      setState(() => _exporting = false);
      _toast(res['message']?.toString() ?? 'Failed to export data');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/agrosetu_export_$ts.json');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(res['data']));
      if (!mounted) return;
      setState(() => _exporting = false);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'privacy.export_share_text'.tr,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      _toast('Saved data but couldn\'t share: $e');
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'privacy.clear_cache'.tr,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'privacy.clear_warn'.tr,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('auth.cancel'.tr, style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'privacy.clear_button'.tr,
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

    setState(() => _clearingCache = true);
    await NotificationService.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('disease_history_cache');
    await prefs.remove('weather_cache');
    await UserPreferencesService.clearCacheOnly();
    if (!mounted) return;
    final p = await UserPreferencesService.load();
    if (!mounted) return;
    setState(() {
      _profileVisibility = p.profileVisibility;
      _activityLogging = p.activityLogging;
      _clearingCache = false;
    });
    _toast('privacy.cache_cleared'.tr);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
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
          'privacy.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('privacy.section_settings'.tr),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        children: [
                          _buildPrivacyItem(
                            'privacy.profile_visibility'.tr,
                            'privacy.profile_visibility_sub'.tr,
                            _profileVisibility,
                            _setProfileVisibility,
                          ),
                          const Divider(height: 20),
                          _buildPrivacyItem(
                            'privacy.activity_logging'.tr,
                            'privacy.activity_logging_sub'.tr,
                            _activityLogging,
                            _setActivityLogging,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('privacy.section_data'.tr),
                    const SizedBox(height: 16),
                    _card(
                      child: Column(
                        children: [
                          _buildSecurityOption(
                            Icons.download_rounded,
                            'privacy.download_data'.tr,
                            'privacy.download_data_sub'.tr,
                            _exporting ? null : _downloadData,
                            trailing: _exporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : null,
                          ),
                          const Divider(height: 20),
                          _buildSecurityOption(
                            Iconsax.trash,
                            'privacy.clear_cache'.tr,
                            'privacy.clear_cache_sub'.tr,
                            _clearingCache ? null : _clearCache,
                            trailing: _clearingCache
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildPrivacyItem(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
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
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF2E7D32),
          activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildSecurityOption(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap, {
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
                      color: Colors.black87,
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
