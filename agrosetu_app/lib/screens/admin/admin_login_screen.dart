import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/user_service.dart';
import 'admin_shell.dart';

/// Dedicated, strict admin login.
///
/// Hits POST /api/admin/login which only succeeds when the account has
/// `isAdmin: true` AND `isActive: true` in MongoDB. Regular farmer accounts
/// get a 403 from the server, never reach the AdminShell, never see admin
/// data. We also rate-limit attempts client-side: 5 wrong tries → 60 second
/// lockout to slow down credential stuffing.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _green = Color(0xFF1B5E20);
  static const _maxAttempts = 5;
  static const _lockoutSeconds = 60;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;
  String? _error;

  int _failedAttempts = 0;
  int _lockoutRemaining = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isLocked => _lockoutRemaining > 0;

  void _startLockout() {
    setState(() => _lockoutRemaining = _lockoutSeconds);
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _lockoutRemaining--);
      if (_lockoutRemaining <= 0) {
        t.cancel();
        _failedAttempts = 0;
      }
    });
  }

  Future<void> _submit() async {
    if (_isLocked) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password required');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final res = await ApiService.adminLogin(email, password);

    if (!mounted) return;

    if (res['status'] == 'ok') {
      // Save admin session — token + user + isAdmin flag.
      final user = Map<String, dynamic>.from(res['user'] ?? {});
      user['token'] = res['token'];
      user['isAdmin'] = true; // server already verified, but be explicit
      await UserService.saveUser(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', res['token']);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_admin_session', true);

      _failedAttempts = 0;

      if (!mounted) return;
      setState(() => _submitting = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminShell()),
        (_) => false,
      );
      return;
    }

    // Failed
    _failedAttempts += 1;
    final remaining = _maxAttempts - _failedAttempts;
    setState(() {
      _submitting = false;
      _error = res['message']?.toString() ?? 'Login failed';
    });

    if (_failedAttempts >= _maxAttempts) {
      _startLockout();
      setState(() {
        _error =
            'Too many failed attempts. Locked for $_lockoutSeconds seconds.';
      });
    } else if (remaining <= 2) {
      setState(() {
        _error = '${_error ?? "Login failed"} ($remaining tries left)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildPasswordField(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildError(),
                ],
                if (_isLocked) ...[
                  const SizedBox(height: 12),
                  _buildLockoutBanner(),
                ],
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _green.withValues(alpha: 0.4), width: 1),
          ),
          child: const Icon(Iconsax.shield_tick, color: Color(0xFF66BB6A), size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Admin Console',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Restricted access. All login attempts are logged.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return _DarkField(
      controller: _emailCtrl,
      label: 'Admin email',
      icon: Iconsax.sms,
      keyboardType: TextInputType.emailAddress,
      enabled: !_submitting && !_isLocked,
      autofillHints: const [AutofillHints.email],
    );
  }

  Widget _buildPasswordField() {
    return _DarkField(
      controller: _passwordCtrl,
      label: 'Password',
      icon: Iconsax.lock,
      obscure: !_showPassword,
      enabled: !_submitting && !_isLocked,
      autofillHints: const [AutofillHints.password],
      onSubmitted: (_) => _submit(),
      suffix: IconButton(
        icon: Icon(
          _showPassword ? Iconsax.eye_slash : Iconsax.eye,
          color: Colors.white54,
          size: 18,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red.shade100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.timer_1, color: Colors.orangeAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Locked for $_lockoutRemaining seconds',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.orange.shade100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: (_submitting || _isLocked) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade800,
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Sign In to Admin',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildHint() {
    return Text(
      'Only accounts with admin privileges can sign in here.\nFarmer accounts will be rejected.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white38,
        height: 1.4,
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white54, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
    );
  }
}
