import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _resetCodeSent = false;
  bool _resetComplete = false;

  void _requestResetCode() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showErrorDialog('forgot.required'.tr, 'forgot.email_required'.tr);
      return;
    }

    if (!email.contains('@')) {
      _showErrorDialog('forgot.invalid_email_title'.tr, 'forgot.invalid_email'.tr);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.requestPasswordReset(email);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['status'] == 'ok') {
        setState(() => _resetCodeSent = true);
        
        // Show dev code only in debug builds. In release we never expose
        // it on-screen even if the backend leaks it in the response.
        final devCode = response['data']?['_devCode'];
        if (devCode != null && kDebugMode) {
          debugPrint('[ForgotPassword] 🔐 Dev reset code: $devCode');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'forgot.code_dev'.tr}$devCode'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('forgot.code_sent'.tr),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showErrorDialog(
          'forgot.request_failed'.tr,
          response['message'] ?? 'forgot.request_failed_msg'.tr,
        );
      }
    } on SocketException {
      setState(() => _isLoading = false);
      _showErrorDialog('login.network_error'.tr, 'forgot.no_internet'.tr);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('common.error'.tr, '${'forgot.unexpected'.tr} $e');
      debugPrint('[ForgotPassword] Error: $e');
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (code.isEmpty) {
      _showErrorDialog('forgot.required'.tr, 'forgot.code_required'.tr);
      return;
    }

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog('forgot.required'.tr, 'forgot.passwords_required'.tr);
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog('forgot.mismatch'.tr, 'forgot.passwords_mismatch'.tr);
      return;
    }

    // Validate new password strength
    final hasUpperCase = RegExp(r'[A-Z]').hasMatch(newPassword);
    final hasLowerCase = RegExp(r'[a-z]').hasMatch(newPassword);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(newPassword);
    final hasSpecialChar = RegExp(r'[!@#$%^&*()_+=\[\]{};:`~<>,./\-]').hasMatch(newPassword);
    final isLengthEnough = newPassword.length >= 8;

    if (!hasUpperCase || !hasLowerCase || !hasNumbers || !hasSpecialChar || !isLengthEnough) {
      _showErrorDialog(
        'forgot.weak'.tr,
        'forgot.weak_msg'.tr,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.resetPassword(email, code, newPassword);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['status'] == 'ok') {
        setState(() => _resetComplete = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('forgot.success_msg'.tr),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        _showErrorDialog('forgot.failed'.tr, response['message'] ?? 'forgot.failed_msg'.tr);
      }
    } on SocketException {
      setState(() => _isLoading = false);
      _showErrorDialog('login.network_error'.tr, 'forgot.no_internet_short'.tr);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('common.error'.tr, 'forgot.unexpected_short'.tr);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.6,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.ok'.tr,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E20)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'forgot.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Indicator
              _buildStepIndicator(),
              
              const SizedBox(height: 32),

              if (!_resetCodeSent && !_resetComplete) ...[
                // Step 1: Enter Email
                _buildEmailStep(),
              ] else if (_resetCodeSent && !_resetComplete) ...[
                // Step 2: Enter Code and New Password
                _buildResetStep(),
              ] else if (_resetComplete) ...[
                // Success Screen
                _buildSuccessScreen(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _resetCodeSent ? Icons.check_circle : Icons.circle_outlined,
            color: _resetCodeSent ? Colors.green : Colors.blue,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _resetCodeSent
                  ? 'forgot.step2'.tr
                  : 'forgot.step1'.tr,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'forgot.enter_email'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'forgot.enter_email_subtitle'.tr,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'forgot.email_label'.tr,
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: _emailController,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestResetCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              disabledBackgroundColor: Colors.grey.shade400,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'forgot.sending'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'forgot.send_code'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'forgot.reset_password'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'forgot.reset_subtitle'.tr,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        // Reset Code
        Text(
          'forgot.reset_code'.tr,
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: _codeController,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            decoration: InputDecoration(
              hintText: 'forgot.reset_code_hint'.tr,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.code,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // New Password
        Text(
          'forgot.new_password'.tr,
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: _newPasswordController,
            obscureText: !_showPassword,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            decoration: InputDecoration(
              hintText: 'forgot.new_password_hint'.tr,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
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
          ),
        ),
        const SizedBox(height: 20),

        // Confirm Password
        Text(
          'forgot.confirm_password'.tr,
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
            decoration: InputDecoration(
              hintText: 'forgot.confirm_hint'.tr,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: Colors.grey.shade500,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              disabledBackgroundColor: Colors.grey.shade400,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'forgot.resetting'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'forgot.reset_password'.tr,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.check,
              color: Colors.green.shade700,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'forgot.success_title'.tr,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'forgot.success_subtitle'.tr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
              ),
              child: Text(
                'forgot.go_login'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
