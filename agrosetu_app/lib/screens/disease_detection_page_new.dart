import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/activity_service.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class DiseaseDetectionPageNew extends StatefulWidget {
  const DiseaseDetectionPageNew({super.key});

  @override
  State<DiseaseDetectionPageNew> createState() =>
      _DiseaseDetectionPageNewState();
}

class _DiseaseDetectionPageNewState extends State<DiseaseDetectionPageNew> {
  Uint8List? _selectedImage;
  bool _isProcessing = false;
  String? _detectedDisease;
  double? _confidence;
  List<String>? _solutions;
  String? _pesticide;
  String? _dosage;
  String? _frequency;
  String? _description;
  String? _errorMessage;

  final List<Map<String, dynamic>> _recentDetections = [];

  void _detectDiseaseFromCamera() async {
    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!isMobile) {
      _showErrorDialog(
          'Camera not available',
          'Your device does not have a camera. Please use Gallery to upload an image.');
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? captured = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (captured == null) {
        return;
      }

      final bytes = await captured.readAsBytes();
      setState(() {
        _selectedImage = bytes;
        _isProcessing = true;
        _errorMessage = null;
      });

      // Pass bytes directly to avoid relying on state timing
      // captured.path can be null on web — pass empty string when null
      await _sendImageToFlask(captured.path ?? '', bytes);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to open camera: $e');
    }
  }

  void _pickFromGallery() async {
    final bool isDesktopOrWeb = kIsWeb ||
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    try {
      Uint8List? bytes;
      String? imagePath;

      if (isDesktopOrWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        bytes = file.bytes;
        // On web `file.path` may be null or throw; use bytes on web and avoid accessing path
        imagePath = kIsWeb ? null : file.path;
        if (bytes == null) {
          _showErrorSnackBar('Selected file cannot be read');
          return;
        }
      } else {
        final ImagePicker picker = ImagePicker();
        final XFile? picked =
            await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        // picked.path is safe on mobile platforms; keep as-is
        imagePath = picked.path;
      }

      if (bytes == null) {
        _showErrorSnackBar('Could not read selected image');
        return;
      }

      setState(() {
        _selectedImage = bytes;
        _isProcessing = true;
        _errorMessage = null;
      });

      // CRITICAL: Pass bytes directly - don't rely on state which hasn't updated yet
      // file.path may be null on web — pass empty string when null
      await _sendImageToFlask(imagePath ?? '', bytes!);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _sendImageToFlask(String imagePath, Uint8List bytes) async {
    try {
      // On web, we have bytes; on mobile, we have file path
      final bool isWeb = kIsWeb;
      
      print('[Disease Detection] Sending image to Flask (isWeb=$isWeb)');
      print('[Disease Detection] Image path: $imagePath');
      print('[Disease Detection] Image bytes: ${bytes.length}');
      
      late Map<String, dynamic> result;
      
      if (isWeb) {
        // Web: use bytes directly (parameter)
        print('[Disease Detection] Using bytes method for web (${bytes.length} bytes)');
        result = await ApiService.predictDiseaseFromImageBytes(bytes);
      } else {
        // Mobile/Desktop: use file path
        print('[Disease Detection] Using file path method for mobile: $imagePath');
        result = await ApiService.predictDiseaseFromImage(imagePath);
      }

      print('[Disease Detection] Result: $result');

      if (result['status'] == 'ok') {
        setState(() {
          _detectedDisease = result['disease_name'];
          _confidence = result['confidence'];
          _solutions = result['solutions'];
          _pesticide = result['pesticide'];
          _dosage = result['dosage'];
          _frequency = result['frequency'];
          _description = result['description'];
          _isProcessing = false;
          _errorMessage = null;
        });

        await ActivityService.addActivity(
          'detection',
          'Disease detected: $_detectedDisease (${_confidence?.toStringAsFixed(1)}%)',
        );

        _addToRecentDetections();
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = result['message'] ?? 'Unknown error occurred';
        });
        _showErrorSnackBar(_errorMessage ?? 'Failed to detect disease');
      }
    } catch (e) {
      print('[Disease Detection] Exception: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error: $e';
      });
      _showErrorSnackBar('Error sending image to server: $e');
    }
  }

  void _addToRecentDetections() {
    if (_detectedDisease != null) {
      final newDetection = {
        'disease': _detectedDisease,
        'confidence': '${_confidence?.toStringAsFixed(1)}%',
        'date': 'Just now',
      };
      setState(() {
        _recentDetections.insert(0, newDetection);
        if (_recentDetections.length > 5) {
          _recentDetections.removeAt(_recentDetections.length - 1);
        }
      });
    }
  }

  void _clearResults() {
    setState(() {
      _selectedImage = null;
      _detectedDisease = null;
      _confidence = null;
      _solutions = null;
      _pesticide = null;
      _dosage = null;
      _frequency = null;
      _description = null;
      _errorMessage = null;
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildUploadCard(),
              if (_errorMessage != null) _buildErrorBanner(),
              if (_detectedDisease != null) _buildResultCard(),
              if (_recentDetections.isNotEmpty) _buildRecentSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Iconsax.camera,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disease Detection',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-powered crop analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: _selectedImage == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.gallery,
                          size: 50,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No image selected',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: _isProcessing
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF2E7D32),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Analyzing image...',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          )
                        : Image.memory(_selectedImage!),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _detectDiseaseFromCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Iconsax.camera, size: 20),
                  label: Text(
                    'Take Photo',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Iconsax.gallery, size: 20),
                  label: Text(
                    'Gallery',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImage != null && !_isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _clearResults,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.warning_2,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analysis Result',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  '${_confidence?.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              _detectedDisease ?? 'Unknown',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900,
              ),
            ),
          ),
          if (_description != null) ...[
            const SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _description!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
          if (_solutions != null && _solutions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recommended Solutions',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ..._solutions!.map((solution) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          solution,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (_pesticide != null && _pesticide != 'None') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesticide Treatment',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Product: $_pesticide',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  if (_dosage != null && _dosage != 'N/A')
                    Text(
                      'Dosage: $_dosage',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  if (_frequency != null && _frequency != 'N/A')
                    Text(
                      'Frequency: $_frequency',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Detections',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 14),
          ..._recentDetections.asMap().entries.map((entry) {
            final detection = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detection['disease'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detection['date'],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      detection['confidence'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
