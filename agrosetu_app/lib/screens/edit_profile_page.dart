import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onSave;

  const EditProfilePage({
    super.key,
    required this.userData,
    required this.onSave,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _farmSizeController;
  late TextEditingController _cropsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name'] ?? '');
    _emailController = TextEditingController(text: widget.userData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _locationController = TextEditingController(text: widget.userData['location'] ?? '');
    _farmSizeController = TextEditingController(text: widget.userData['farmSize'] ?? '');
    _cropsController = TextEditingController(
      text: (widget.userData['mainCrops'] as List?)?.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _farmSizeController.dispose();
    _cropsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final farmSize = _farmSizeController.text.trim();
    final crops = _cropsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('edit_profile.name_required'.tr)),
      );
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('edit_profile.invalid_email'.tr)),
      );
      return;
    }

    setState(() => _isLoading = true);

    final updatedData = {
      ...widget.userData,
      'name': name,
      'email': email,
      'phone': phone,
      'location': location,
      'farmSize': farmSize,
      'mainCrops': crops,
    };

    // Save locally first so the UI is responsive even if the network is slow.
    await UserService.updateUser(updatedData);

    String? backendError;
    final userId = widget.userData['id']?.toString();
    if (userId != null && userId != 'N/A') {
      final res = await ApiService.updateProfile(
        userId: userId,
        name: name,
        email: email.isEmpty ? null : email,
        phone: phone,
        location: location,
        farmSize: farmSize,
        mainCrops: crops,
      );
      if (res['status'] == 'ok' && res['user'] is Map) {
        final remote = Map<String, dynamic>.from(res['user']);
        updatedData['name'] = remote['name'] ?? updatedData['name'];
        updatedData['email'] = remote['email'] ?? updatedData['email'];
        updatedData['phone'] = remote['phone'] ?? updatedData['phone'];
        updatedData['location'] = remote['location'] ?? updatedData['location'];
        updatedData['farmSize'] = remote['farmSize'] ?? updatedData['farmSize'];
        if (remote['mainCrops'] is List) {
          updatedData['mainCrops'] = List<String>.from(remote['mainCrops']);
        }
        await UserService.updateUser(updatedData);
      } else if (res['status'] != 'ok') {
        backendError = res['message']?.toString();
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    widget.onSave(updatedData);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(backendError == null
            ? 'edit_profile.updated'.tr
            : '${'edit_profile.saved_local'.tr} $backendError'),
        backgroundColor: backendError == null ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'edit_profile.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField('edit_profile.name'.tr, _nameController, Iconsax.user),
            const SizedBox(height: 16),
            _buildTextField('edit_profile.email'.tr, _emailController, Iconsax.sms, isEmail: true),
            const SizedBox(height: 16),
            _buildTextField('edit_profile.phone'.tr, _phoneController, Iconsax.call),
            const SizedBox(height: 16),
            _buildTextField('edit_profile.location'.tr, _locationController, Iconsax.location),
            const SizedBox(height: 16),
            _buildTextField('edit_profile.farm_size'.tr, _farmSizeController, Iconsax.home),
            const SizedBox(height: 16),
            _buildTextField(
              'edit_profile.crops'.tr,
              _cropsController,
              Iconsax.menu,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'edit_profile.save'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isEmail = false,
    int maxLines = 1,
  }) {
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
        maxLines: maxLines,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }
}
