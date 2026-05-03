import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:async'; // Added for Timer
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _isVerifying = false; 
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Timer variables for Resend OTP
  Timer? _timer;
  int _start = 30;
  bool _canResend = false;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 30;
      _canResend = false;
    });
    _timer?.cancel(); // Cancel any existing timer before starting a new one
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'signup.pw_required'.tr;
    }

    final RegExp hasUpperCase = RegExp(r'[A-Z]');
    final RegExp hasLowerCase = RegExp(r'[a-z]');
    final RegExp hasNumbers = RegExp(r'[0-9]');
    final RegExp hasSpecialChar = RegExp(r'[!@#$%^&*()_+=\[\]{};:`~<>,./\-]');

    if (value.length < 8) {
      return 'signup.pw_min_length'.tr;
    }
    if (!hasUpperCase.hasMatch(value)) {
      return 'signup.pw_upper'.tr;
    }
    if (!hasLowerCase.hasMatch(value)) {
      return 'signup.pw_lower'.tr;
    }
    if (!hasNumbers.hasMatch(value)) {
      return 'signup.pw_number'.tr;
    }
    if (!hasSpecialChar.hasMatch(value)) {
      return 'signup.pw_special'.tr;
    }

    return null;
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final response = await ApiService.signup(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        // FIX: Server returns status:'pending' when OTP is sent successfully.
        // Old code checked for 'ok' which never matched, so OTP screen never appeared.
        if (response['status'] == 'pending' || response['status'] == 'ok') {
          setState(() {
            _isVerifying = true; 
          });
          _startTimer(); // Start countdown when moving to OTP screen

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${'signup.otp_sent_prefix'.tr}${_emailController.text.trim()}${'signup.otp_sent_suffix'.tr}'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else {
          final errorMsg = response['message'] ?? 'signup.signup_failed'.tr;
          final backendErrors = response['errors'];
          
          if (mounted) {
            String fullErrorMsg = errorMsg;
            if (backendErrors is List && backendErrors.isNotEmpty) {
              fullErrorMsg += '\n\n${backendErrors.join('\n')}';
            }
            _showErrorDialog('signup.registration_failed'.tr, fullErrorMsg);
          }
        }
      } on SocketException {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('login.network_error'.tr, 'signup.no_internet'.tr);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('common.error'.tr, '${'signup.error_occurred'.tr} $e');
        }
      }
    }
  }

  void _verifyOtp() async {
    if (_otpFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final response = await ApiService.verifyOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        if (response['status'] == 'ok') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('signup.email_verified'.tr),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        } else {
          _showErrorDialog('signup.verification_failed'.tr, response['message'] ?? 'signup.invalid_otp'.tr);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('common.error'.tr, '${'signup.verification_error'.tr} $e');
        }
      }
    }
  }

  // FIX: _resendCode now correctly calls ApiService.resendOtp instead of
  // forgotPassword (which is for password resets, not signup verification).
  void _resendCode() async {
    if (!_canResend) return;
    
    setState(() => _isLoading = true);

    final response = await ApiService.resendOtp(_emailController.text.trim());
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (response['status'] == 'ok') {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'signup.otp_resent_prefix'.tr}${_emailController.text.trim()}${'signup.otp_resent_suffix'.tr}'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      _showErrorDialog('common.error'.tr, response['message'] ?? 'signup.failed_resend'.tr);
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    Color strengthColor = Colors.grey;
    String strengthText = 'signup.pw_strength_weak'.tr;

    if (password.isEmpty) return const SizedBox.shrink();

    final hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowerCase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*()_+=\[\]{};:`~<>,./\-]').hasMatch(password);
    final isLengthEnough = password.length >= 8;

    int strength = 0;
    if (hasUpperCase) strength++;
    if (hasLowerCase) strength++;
    if (hasNumbers) strength++;
    if (hasSpecialChar) strength++;
    if (isLengthEnough) strength++;

    if (strength <= 2) { strengthColor = Colors.red; strengthText = 'signup.pw_strength_weak'.tr; }
    else if (strength <= 3) { strengthColor = Colors.orange; strengthText = 'signup.pw_strength_fair'.tr; }
    else if (strength <= 4) { strengthColor = Colors.amber; strengthText = 'signup.pw_strength_good'.tr; }
    else { strengthColor = Colors.green; strengthText = 'signup.pw_strength_strong'.tr; }
    
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: strength / 5,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Text(strengthText, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: strengthColor)),
      ],
    );
  }
  
  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowerCase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*()_+=\[\]{};:`~<>,./\-]').hasMatch(password);
    final isLengthEnough = password.length >= 8;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('signup.pw_requirements'.tr, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _buildRequirementRow('signup.pw_req_length'.tr, isLengthEnough),
          _buildRequirementRow('signup.pw_req_upper'.tr, hasUpperCase),
          _buildRequirementRow('signup.pw_req_lower'.tr, hasLowerCase),
          _buildRequirementRow('signup.pw_req_number'.tr, hasNumbers),
          _buildRequirementRow('signup.pw_req_special'.tr, hasSpecialChar),
        ],
      ),
    );
  }
  
  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.circle_outlined, size: 16, color: isMet ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(fontSize: 12, color: isMet ? Colors.green : Colors.grey.shade600, fontWeight: isMet ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_isVerifying) {
                            // Go back to signup form, cancel OTP timer
                            _timer?.cancel();
                            setState(() => _isVerifying = false);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          _isVerifying ? 'signup.verify_email'.tr : 'signup.create_account'.tr,
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Invisible icon to keep title centered
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Logo Section
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('ماله', style: GoogleFonts.notoSansArabic(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                          Text('AGROSETU', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dynamic Form Container — switches between signup and OTP
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Container(
                      key: ValueKey(_isVerifying), // Key forces AnimatedSwitcher to animate between states
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 25, offset: const Offset(0, 12))],
                      ),
                      child: _isVerifying ? _buildOtpForm() : _buildSignupForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ======= OTP FORM VIEW =======
  Widget _buildOtpForm() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('signup.otp_title'.tr, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20))),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              children: [
                TextSpan(text: 'signup.otp_sent_to'.tr),
                TextSpan(
                  text: _emailController.text.trim(),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofocus: true,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
                letterSpacing: 10,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: GoogleFonts.poppins(letterSpacing: 10, color: Colors.grey.shade300, fontSize: 28),
                border: InputBorder.none,
                counterText: '', // Hide the maxLength counter
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'signup.otp_required'.tr;
                if (value.trim().length < 6) return 'signup.otp_short'.tr;
                return null;
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Resend Timer Section
          Center(
            child: _canResend
              ? TextButton.icon(
                  onPressed: _isLoading ? null : _resendCode,
                  icon: const Icon(Icons.refresh, color: Color(0xFF2E7D32)),
                  label: Text(
                    'signup.resend'.tr,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${'signup.resend_in'.tr} $_start ${'signup.seconds'.tr}',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: _isLoading
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text('signup.verify_continue'.tr, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                _timer?.cancel();
                setState(() => _isVerifying = false);
              },
              child: Text(
                'signup.wrong_email'.tr,
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= SIGNUP FORM VIEW =======
  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('signup.create_your_account'.tr, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20))),
          const SizedBox(height: 8),
          Text('signup.tagline'.tr, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 28),

          Text('signup.full_name'.tr, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _buildTextField(_nameController, 'signup.full_name_hint'.tr, Icons.person_outline),

          const SizedBox(height: 20),

          Text('signup.email'.tr, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _buildTextField(_emailController, 'signup.email_hint'.tr, Icons.email_outlined, isEmail: true),

          const SizedBox(height: 24),

          Text('signup.password'.tr, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _buildPasswordField(
            _passwordController,
            'signup.password_hint'.tr,
            _showPassword,
            (val) => setState(() => _showPassword = !_showPassword),
          ),

          const SizedBox(height: 14),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 14),
          _buildPasswordRequirements(),

          const SizedBox(height: 24),

          Text('signup.confirm_password'.tr, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          _buildPasswordField(
            _confirmPasswordController,
            'signup.confirm_hint'.tr,
            _showConfirmPassword,
            (val) => setState(() => _showConfirmPassword = !_showConfirmPassword),
            isConfirm: true,
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: _isLoading
                ? const SizedBox(
                    height: 24, width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text('signup.button'.tr, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSignInLink(),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isEmail = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey.shade500),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'signup.field_required'.tr;
          if (isEmail && !value.contains('@')) return 'signup.email_invalid'.tr;
          return null;
        },
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String hint,
    bool isVisible,
    Function(bool) toggle, {
    bool isConfirm = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        onChanged: isConfirm ? null : (_) => setState(() {}), // Rebuild for strength indicator
        style: GoogleFonts.poppins(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade500,
            ),
            onPressed: () => toggle(isVisible),
          ),
        ),
        validator: isConfirm
          ? (value) {
              if (value == null || value.isEmpty) return 'signup.confirm_required'.tr;
              if (value != _passwordController.text) return 'signup.pw_mismatch'.tr;
              return null;
            }
          : _validatePassword,
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('signup.have_account'.tr, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ),
          child: Text(
            'signup.signin'.tr,
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}