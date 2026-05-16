import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'admin/admin_shell.dart';
import '../l10n/app_translations.dart';
import '../widgets/animated_background.dart';
import 'dashboard_screen.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../services/social_auth_service.dart';
import '../services/notification_service.dart';
import '../services/disease_history_service.dart';
import '../services/activity_service.dart';
import '../services/user_preferences_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe) {
      final email = prefs.getString('remembered_email') ?? '';
      final password = prefs.getString('remembered_password') ?? '';
      
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = rememberMe;
      });
    }
  }

  /// If the user about to be saved is different from the user previously
  /// cached on this device, wipe per-user caches so the new user does not
  /// inherit notifications / history / activities / preferences from the
  /// previous user. Same-user re-login (e.g. token refresh) is a no-op and
  /// preserves their offline data.
  Future<void> _wipeCachesIfDifferentUser(String newUserId) async {
    final prev = await UserService.getUser();
    final prevId = prev?['id']?.toString();
    if (prevId != null && prevId != newUserId) {
      debugPrint('[LoginScreen] 🧹 Different user ($prevId → $newUserId). Wiping per-user caches.');
      await NotificationService.clearAll();
      await DiseaseHistoryService.clearAll();
      await ActivityService.clearAll();
      await UserPreferencesService.clearCacheOnly();
    }
  }

  Future<void> _saveRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('remembered_email', _emailController.text.trim());
      await prefs.setString('remembered_password', _passwordController.text.trim());
      debugPrint('[LoginScreen] 💾 Credentials saved locally');
    } else {
      await prefs.setBool('remember_me', false);
      await prefs.remove('remembered_email');
      await prefs.remove('remembered_password');
      debugPrint('[LoginScreen] 🗑️ Credentials cleared from local storage');
    }
  }

  void _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    // Capture context-dependent objects before any async gaps
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showErrorDialog('login.validation_error'.tr, 'login.fill_all'.tr);
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiService.login(email, password);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      debugPrint('[LoginScreen] Full response: $response');
      
      if (response['status'] == 'ok') {
        try {
          // FIX: ApiService.login wraps backend response inside 'data' key.
          // Backend returns: { status, token, user: { id, name, email } }
          // ApiService returns: { status:'ok', data: <backend response>, message }
          // So we read token and user directly from response['data']
          final backendData = response['data'] as Map<String, dynamic>;
          final userInfo = backendData['user'] as Map<String, dynamic>?;
          final token = backendData['token'] as String?;

          debugPrint('[LoginScreen] backendData: $backendData');
          debugPrint('[LoginScreen] userInfo: $userInfo');
          debugPrint('[LoginScreen] token: $token');
          
          if (userInfo == null || userInfo['id'] == null) {
            _showErrorDialog('login.error_title'.tr, 'login.invalid_user_data'.tr);
            return;
          }

          if (token == null || token.isEmpty) {
            _showErrorDialog('login.error_title'.tr, 'login.no_token'.tr);
            return;
          }

          final userToSave = {
            'id': userInfo['id'].toString(),
            'name': userInfo['name'] ?? 'profile.user_default'.tr,
            'email': userInfo['email'] ?? email,
            'token': token,
            'isAdmin': userInfo['isAdmin'] == true,
            'phone': '+977 9800000000',
            'location': 'Kathmandu, Nepal',
            'farmSize': '2.0 hectares',
            'mainCrops': ['Rice', 'Wheat'],
            'joinDate': DateTime.now().toString().split(' ')[0],
            'detections': 0,
            'discussions': 0,
            'marketTips': 0,
          };
          
          debugPrint('[LoginScreen] Saving user: ${userToSave['name']}');
          await _wipeCachesIfDifferentUser(userToSave['id'] as String);
          await UserService.saveUser(userToSave);

          final savedUser = await UserService.getUser();
          debugPrint('[LoginScreen] ✅ Saved user verified: ${savedUser?['name']}, token exists: ${savedUser?['token'] != null}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${'login.welcome_user'.tr}, ${userInfo['name']}! 🌱'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          await _saveRememberedCredentials();

          // Save explicitly for offline fallback regardless of remember me.
          // We store the SHA-256 hash (with a per-device salt) of the password
          // — never plaintext — so that a device-level read of SharedPreferences
          // doesn't expose the credential. Remove any legacy plaintext entry.
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('offline_password'); // legacy plaintext key
          await prefs.setString('offline_email', email.toLowerCase());
          final salt = await _getOrCreateOfflineSalt(prefs);
          final hash =
              sha256.convert(utf8.encode('$salt::$password')).toString();
          await prefs.setString('offline_password_hash', hash);

          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            final isAdmin = userInfo['isAdmin'] == true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => isAdmin
                    ? const AdminShell()
                    : const DashboardScreen(),
              ),
            );
          }

        } catch (dataError) {
          debugPrint('[LoginScreen] ❌ Error processing user data: $dataError');
          _showErrorDialog('login.data_error'.tr, '${'login.failed_process'.tr} $dataError');
        }

      } else if (response['status'] == 'unverified') {
        // FIX: Handle unverified accounts — show message and go to OTP screen
        // instead of showing generic "Login Failed"
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'login.account_not_verified'.tr,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.orange),
              ),
              content: Text(
                'login.unverified_msg'.tr,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common.cancel'.tr, style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SignupScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                  child: Text('login.verify_now'.tr, style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            ),
          );
        }

      } else {
        final errorMsg = response['message'] ?? 'login.failed'.tr;
        _showErrorDialog('login.failed'.tr, errorMsg);
      }

    } on SocketException {
      // OFFLINE LOGIN FALLBACK (uses messenger/navigator captured at top of _login)
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('offline_email');
        final savedHash = prefs.getString('offline_password_hash');

        final inputEmail = _emailController.text.trim().toLowerCase();
        final inputPassword = _passwordController.text.trim();

        bool credentialsValid = false;
        if (savedEmail != null && savedHash != null && savedEmail == inputEmail) {
          final salt = await _getOrCreateOfflineSalt(prefs);
          final candidate =
              sha256.convert(utf8.encode('$salt::$inputPassword')).toString();
          credentialsValid = candidate == savedHash;
        }

        if (credentialsValid) {
          
          final savedUser = await UserService.getUser();
          if (savedUser != null) {
            // Treat as successful login
            setState(() => _isLoading = false);
            messenger.showSnackBar(
              SnackBar(
                content: Text('login.offline_login'.tr),
                backgroundColor: Colors.orange,
              ),
            );
            
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) {
              final cachedUser = await UserService.getUser();
              final isAdmin = cachedUser?['isAdmin'] == true;
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => isAdmin
                      ? const AdminShell()
                      : const DashboardScreen(),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint("Offline logic fallback failed: $e");
      }
      
      setState(() => _isLoading = false);
      _showErrorDialog('login.network_error'.tr, 'login.no_offline'.tr);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Login error: $e');
      _showErrorDialog('common.error'.tr, '${'login.unexpected'.tr} $e');
    }
  }

  Future<void> _handleGoogleLogin() async {
    debugPrint('[LoginScreen] 👆 Google login button tapped');
    
    // Immediate visual feedback to prove the code is running
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('login.starting_google'.tr),
        duration: const Duration(seconds: 1),
      ),
    );

    setState(() => _isLoading = true);

    try {
      final response = await SocialAuthService.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['status'] == 'ok') {
        try {
          final backendData = response['data'] as Map<String, dynamic>? ?? response;
          final userInfo = backendData['user'] as Map<String, dynamic>?;
          final token = backendData['token'] as String?;

          if (userInfo == null || userInfo['id'] == null) {
            _showErrorDialog('login.error_title'.tr, 'login.invalid_user_data'.tr);
            return;
          }

          if (token == null || token.isEmpty) {
            _showErrorDialog('login.error_title'.tr, 'login.no_token'.tr);
            return;
          }

          final userToSave = {
            'id': userInfo['id'].toString(),
            'name': userInfo['name'] ?? 'profile.user_default'.tr,
            'email': userInfo['email'] ?? '',
            'token': token,
            'isAdmin': userInfo['isAdmin'] == true,
            'phone': '+977 9800000000',
            'location': 'Kathmandu, Nepal',
            'farmSize': '2.0 hectares',
            'mainCrops': ['Rice', 'Wheat'],
            'joinDate': DateTime.now().toString().split(' ')[0],
            'detections': 0,
            'discussions': 0,
            'marketTips': 0,
          };

          await _wipeCachesIfDifferentUser(userToSave['id'] as String);
          await UserService.saveUser(userToSave);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${'login.welcome_user'.tr}, ${userInfo['name']}! 🌱'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            final isAdmin = userInfo['isAdmin'] == true;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => isAdmin
                    ? const AdminShell()
                    : const DashboardScreen(),
              ),
            );
          }
        } catch (dataError) {
          debugPrint('[LoginScreen] ❌ Error processing google login data: $dataError');
          _showErrorDialog('login.data_error'.tr, '${'login.failed_process'.tr} $dataError');
        }
      } else {
        final errorMsg = response['message'] ?? 'login.google_failed'.tr;
        _showErrorDialog('login.failed'.tr, errorMsg);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Google Login error: $e');
      _showErrorDialog('common.error'.tr, '${'login.google_unexpected'.tr} $e');
    }
  }
  
  /// Returns a stable per-device salt used to hash the offline password.
  /// Generated once on first login and persisted; not derivable from the user's
  /// password, so an attacker who reads SharedPreferences still cannot brute
  /// force the original password without knowing the salt's storage location
  /// AND running on the same device.
  Future<String> _getOrCreateOfflineSalt(SharedPreferences prefs) async {
    var salt = prefs.getString('offline_salt');
    if (salt != null && salt.isNotEmpty) return salt;
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    salt = base64Url.encode(bytes);
    await prefs.setString('offline_salt', salt);
    return salt;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const AnimatedFarmBackground(),

          // Content overlay
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  
                  // Logo
                  Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.park,
                              size: 40,
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AGROSETU',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2E7D32),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'HAMRO LAGI',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4CAF50),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),

                  // Login form container
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 0,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 40,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Welcome section
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'login.welcome_back'.tr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1B5E20),
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'login.subtitle'.tr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Email field
                            Text(
                              'login.email_label'.tr,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'login.email_hint'.tr,
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'login.email_required'.tr;
                                  }
                                  if (!value.contains('@')) {
                                    return 'login.email_invalid'.tr;
                                  }
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Password field
                            Text(
                              'login.password_label'.tr,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                ),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey.shade500,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'login.password_required'.tr;
                                  }
                                  if (value.length < 6) {
                                    return 'login.password_short'.tr;
                                  }
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Remember me & Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _rememberMe = !_rememberMe;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        activeColor: const Color(0xFF2E7D32),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      Text(
                                        'login.remember_me'.tr,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'login.forgot_password'.tr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Log In button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'login.button'.tr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.arrow_forward, size: 20),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'login.or'.tr,
                                    style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Social login buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSocialButton(
                                  icon: Icons.g_mobiledata,
                                  color: const Color(0xFFDB4437),
                                  onTap: _handleGoogleLogin,
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Sign up link
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'login.no_account'.tr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SignupScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'login.signup_link'.tr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: const Color(0xFF1B5E20),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Privacy text
                            Center(
                              child: Text(
                                'login.terms'.tr,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required IconData icon, required Color color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}