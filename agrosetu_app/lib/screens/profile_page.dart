import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'login_screen.dart';
import '../l10n/app_translations.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../services/user_preferences_service.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'privacy_security_page.dart';
import 'terms_conditions_page.dart';
import 'contact_support_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  bool _togglingNotifications = false;
  Map<String, dynamic>? _userData;
  Uint8List? _profileImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await UserPreferencesService.load();
    if (!mounted) return;
    setState(() => _notificationsEnabled = prefs.notificationsEnabled);
    // Reconcile with backend in the background.
    UserPreferencesService.refreshFromBackend().then((p) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = p.notificationsEnabled);
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
      _togglingNotifications = true;
    });
    final updated =
        await UserPreferencesService.update(notificationsEnabled: value);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = updated.notificationsEnabled;
      _togglingNotifications = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'profile.notifications_enabled'.tr
            : 'profile.notifications_muted'.tr),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadUserData() async {
    try {
      // Give cache time to populate if this is immediate call
      await Future.delayed(const Duration(milliseconds: 100));
      
      final user = await UserService.getUser();
      
      if (!mounted) return;
      
      if (user == null) {
        // User not logged in - redirect to login
        debugPrint('[ProfilePage] No user data, redirecting to login');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      debugPrint('[ProfilePage] User data loaded: ${user['name']}');
      setState(() {
        _userData = {
          'id': user['id'] ?? 'N/A',
          'name': user['name'] ?? 'profile.user_default'.tr,
          'email': user['email'] ?? 'user@agrosetu.com',
          'phone': user['phone'] ?? '+977 9800000000',
          'location': user['location'] ?? 'Kathmandu, Nepal',
          'farmSize': user['farmSize'] ?? '2.0 hectares',
          'mainCrops': user['mainCrops'] ?? ['Rice', 'Wheat'],
          'joinDate': user['joinDate'] ?? DateTime.now().toString().split(' ')[0],
          'detections': user['detections'] ?? 0,
          'discussions': user['discussions'] ?? 0,
          'marketTips': user['marketTips'] ?? 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final imageBase64 = await UserService.getProfileImage();
    if (imageBase64 != null) {
      try {
        final bytes = base64Decode(imageBase64);
        setState(() {
          _profileImage = bytes;
        });
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = base64Encode(bytes);
        await UserService.saveProfileImage(base64String);
        
        setState(() {
          _profileImage = bytes;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('profile.picture_updated'.tr),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _navigateToPage(String action) {
    switch (action) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
        break;
      case 'privacy':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PrivacySecurityPage()),
        );
        break;
      case 'terms':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TermsConditionsPage()),
        );
        break;
      case 'support':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactSupportPage()),
        );
        break;
    }
  }


  List<Map<String, dynamic>> get _menuItems => [
        {'icon': Iconsax.setting, 'label': 'profile.menu.settings'.tr, 'action': 'settings'},
        {'icon': Iconsax.shield_tick, 'label': 'profile.menu.privacy'.tr, 'action': 'privacy'},
        {'icon': Iconsax.document, 'label': 'profile.menu.terms'.tr, 'action': 'terms'},
        {'icon': Iconsax.call, 'label': 'profile.menu.support'.tr, 'action': 'support'},
      ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildStatsSection(),
              _buildFarmInfoSection(),
              _buildPreferencesSection(),
              _buildMenuSection(),
              _buildLogoutButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2E7D32),
                      Color(0xFF1B5E20),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _profileImage != null
                    ? ClipOval(
                        child: Image.memory(
                          _profileImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        Iconsax.user,
                        size: 50,
                        color: Colors.white,
                      ),
              ),
              GestureDetector(
                onTap: _pickProfileImage,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E7D32),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Iconsax.camera,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userData?['name'] ?? 'profile.user_default'.tr,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.location,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                _userData?['location'] ?? 'profile.location'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfilePage(
                      userData: _userData ?? {},
                      onSave: (updatedData) {
                        setState(() {
                          _userData = updatedData;
                        });
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'profile.edit'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final stats = [
      {'label': 'profile.detections'.tr, 'value': '${_userData?['detections'] ?? 0}', 'icon': Iconsax.camera},
      {'label': 'profile.discussions'.tr, 'value': '${_userData?['discussions'] ?? 0}', 'icon': Iconsax.message},
      {'label': 'profile.market_tips'.tr, 'value': '${_userData?['marketTips'] ?? 0}', 'icon': Iconsax.chart},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats.map((stat) {
          return Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: const Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                stat['value'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['label'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFarmInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.farm_information'.tr,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('profile.farm_size'.tr, _userData?['farmSize'] ?? '0 hectares', Iconsax.home),
          const SizedBox(height: 12),
          _buildInfoRow('profile.main_crops'.tr, (_userData?['mainCrops'] as List?)?.join(', ') ?? '-', Iconsax.menu),
          const SizedBox(height: 12),
          _buildInfoRow('profile.member_since'.tr, _userData?['joinDate'] ?? '-', Iconsax.calendar),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
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
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.preferences'.tr,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 12),
          _buildPreferenceRow(
            'profile.notifications'.tr,
            _notificationsEnabled,
            _togglingNotifications ? null : _toggleNotifications,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(
    String label,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2E7D32),
            activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
            activeThumbImage: null,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_menuItems.length, (index) {
          final item = _menuItems[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Icon(
              item['icon'] as IconData,
              color: const Color(0xFF2E7D32),
              size: 20,
            ),
            title: Text(
              item['label'],
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            trailing: Icon(
              Iconsax.arrow_right_3,
              size: 16,
              color: Colors.grey.shade400,
            ),
            onTap: () => _navigateToPage(item['action']),
          );
        }),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          _showLogoutDialog();
        },
        icon: const Icon(Iconsax.logout),
        label: Text(
          'auth.logout'.tr,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'auth.logout'.tr,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'auth.logout_confirm'.tr,
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'auth.cancel'.tr,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(context); // Close dialog
              
              // Clear all session data
              await UserService.logout();
              await ApiService.logout();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              await prefs.remove('is_logged_in');

              // Navigate after async operations using captured navigator
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
  }
}

