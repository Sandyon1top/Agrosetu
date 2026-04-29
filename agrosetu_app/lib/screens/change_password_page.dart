import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import 'forgot_password_screen.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String pw) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pw);
    final hasLower = RegExp(r'[a-z]').hasMatch(pw);
    final hasNumber = RegExp(r'[0-9]').hasMatch(pw);
    final hasSpecial = RegExp(r'[!@#$%^&*()_+=\[\]{};:`~<>,./\-]').hasMatch(pw);
    return pw.length >= 8 && hasUpper && hasLower && hasNumber && hasSpecial;
  }

  Future<void> _submit() async {
    final currentPw = _currentController.text;
    final newPw = _newController.text;
    final confirmPw = _confirmController.text;

    if (currentPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _toast('pw.required'.tr);
      return;
    }
    if (newPw != confirmPw) {
      _toast('pw.mismatch'.tr);
      return;
    }
    if (!_isStrongPassword(newPw)) {
      _toast('pw.weak'.tr);
      return;
    }
    if (currentPw == newPw) {
      _toast('pw.same'.tr);
      return;
    }

    final user = await UserService.getUser();
    final userId = user?['id']?.toString();
    if (userId == null) {
      _toast('settings.not_signed_in'.tr);
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ApiService.changePassword(
      userId: userId,
      currentPassword: currentPw,
      newPassword: newPw,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['status'] == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('pw.changed'.tr),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      _toast(res['message']?.toString() ?? 'Failed to change password');
    }
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
          'pw.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pw.subtitle'.tr,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            _buildPwField('pw.current'.tr, _currentController, _showCurrent,
                () => setState(() => _showCurrent = !_showCurrent)),
            const SizedBox(height: 16),
            _buildPwField('pw.new'.tr, _newController, _showNew,
                () => setState(() => _showNew = !_showNew)),
            const SizedBox(height: 16),
            _buildPwField('pw.confirm'.tr, _confirmController,
                _showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Text(
                'pw.hint'.tr,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green.shade900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'pw.update'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'pw.forgot'.tr,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPwField(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle,
  ) {
    return Container(
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
      child: TextField(
        controller: controller,
        obscureText: !visible,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          prefixIcon:
              const Icon(Iconsax.lock, color: Color(0xFF2E7D32), size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              visible ? Iconsax.eye_slash : Iconsax.eye,
              color: Colors.grey.shade500,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }
}
