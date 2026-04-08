import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/activity_service.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import '../services/disease_history_service.dart';

class DiseaseDetectionPage extends StatefulWidget {
  const DiseaseDetectionPage({super.key});

  @override
  State<DiseaseDetectionPage> createState() =>
      _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
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
  Map<String, dynamic>? _modelResults;
  Map<String, dynamic>? _instanceAnalysis;

  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await DiseaseHistoryService.getLocalHistory();
    if (mounted && history.isNotEmpty) {
      setState(() {
        _recentDetections.clear();
        // Load the 5 most recent detections for the UI preview
        for (var i = 0; i < history.length && i < 5; i++) {
          final item = history[i];
          _recentDetections.add({
            'disease': item['disease'],
            'confidence': item['confidence'],
            'date': DateTime.tryParse(item['date']) ?? DateTime.now(),
          });
        }
      });
    }
  }

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

      setState(() {
        _selectedImage = bytes;
        _isProcessing = true;
        _errorMessage = null;
      });

      // CRITICAL: Pass bytes directly - don't rely on state which hasn't updated yet
      // file.path may be null on web — pass empty string when null
      await _sendImageToFlask(imagePath ?? '', bytes);
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
      
      debugPrint('[Disease Detection] Sending image to Flask (isWeb=$isWeb)');
      debugPrint('[Disease Detection] Image path: $imagePath');
      debugPrint('[Disease Detection] Image bytes: ${bytes.length}');
      
      late Map<String, dynamic> result;
      
      if (isWeb) {
        debugPrint('[Disease Detection] Using bytes method for web (${bytes.length} bytes)');
        result = await ApiService.predictDiseaseFromImageBytes(bytes, endpoint: '/predict/compare');
      } else {
        debugPrint('[Disease Detection] Using file path method for mobile: $imagePath');
        result = await ApiService.predictDiseaseFromImage(imagePath, endpoint: '/predict/compare');
      }

      debugPrint('[Disease Detection] Result: $result');

      if (result['status'] == 'ok') {
        setState(() {
          _modelResults = result['model_results'];
          _instanceAnalysis = result['instance_analysis'];
          
          if (result['groq_advice'] != null) {
            final best = result['instance_analysis']?['best_model'] ?? result['best_model'];
            final advice = result['groq_advice'];
            _detectedDisease = advice['disease_name'];
            _confidence = _modelResults?[best]?['confidence']?.toDouble();
            _solutions = List<String>.from(advice['solutions'] ?? []);
            _pesticide = advice['pesticide'];
            _dosage = advice['dosage'];
            _frequency = advice['frequency'];
            _description = advice['description'];
          }
          
          _isProcessing = false;
          _errorMessage = null;
        });

        await ActivityService.addActivity(
          'detection',
          'Disease detected: $_detectedDisease (${_confidence?.toStringAsFixed(1)}%)',
        );

        await DiseaseHistoryService.addDetection(
          _detectedDisease ?? 'Unknown',
          _confidence?.toStringAsFixed(1) ?? '0.0',
          List<String>.from(_solutions ?? []),
        );

        _addToRecentDetections();
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = result['message'] ?? 'Unknown error occurred';
          _detectedDisease = null;
          _confidence = null;
          _solutions = null;
          _pesticide = null;
          _dosage = null;
          _frequency = null;
          _description = null;
          _modelResults = null;
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
      _modelResults = null;
    });
  }

  Future<void> _downloadImage() async {
    try {
      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 10));
      if (imageBytes != null) {
        if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
           // Use share_plus to trigger download/sharing on Web and Desktop
           final xFile = XFile.fromData(
             imageBytes, 
             mimeType: 'image/png', 
             name: 'Disease_Result_${DateTime.now().millisecondsSinceEpoch}.png'
           );
           await Share.shareXFiles([xFile], text: 'Disease Detection Result');
           _showErrorSnackBar('Download triggered successfully!');
        } else {
          final result = await ImageGallerySaver.saveImage(
              imageBytes,
              quality: 100,
              name: "Disease_Result_${DateTime.now().millisecondsSinceEpoch}");
          if (result['isSuccess'] == true) {
            _showErrorSnackBar('Result saved to gallery successfully!');
          } else {
            _showErrorSnackBar('Failed to save image.');
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error saving image: $e');
    }
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
      backgroundColor: const Color(0xFFF1F5F0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── PAGE TITLE ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Disease Detection',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showHistoryBottomSheet(context),
                        icon: const Icon(Icons.history, color: Color(0xFF2E7D32)),
                        tooltip: 'Detection History',
                      ),
                    ],
                  ),
                ),

                // ── LARGE IMAGE PREVIEW ─────────────────────────────────
                _buildImagePreview(),

                const SizedBox(height: 14),

                // ── PHOTO / GALLERY BUTTONS ─────────────────────────────
                _buildPhotoCaptureRow(),

                const SizedBox(height: 14),

                // ── ERROR BANNER ────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 14),
                ],

                // ── MODEL CARDS 2×2 GRID ────────────────────────────────
                _buildModelGrid(),

                const SizedBox(height: 14),

                // ── COMPARISON / HISTORY BUTTONS ────────────────────────
                _buildComparisonHistoryRow(),

                const SizedBox(height: 14),

                // ── RESULT DETAILS (screenshot-wrapped) ─────────────────
                if (_detectedDisease != null)
                  Screenshot(
                    controller: _screenshotController,
                    child: _buildResultDetails(),
                  ),

                // ── DOWNLOAD BUTTON (always visible at bottom) ──────────
                const SizedBox(height: 14),
                _buildDownloadButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // LARGE IMAGE PREVIEW
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildImagePreview() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _selectedImage == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.gallery, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'No image selected',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap Photo or Gallery below',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          : _isProcessing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF2E7D32)),
                      const SizedBox(height: 14),
                      Text(
                        'Analyzing image...',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_selectedImage!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearResults,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PHOTO / GALLERY ROW
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildPhotoCaptureRow() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Photo',
            icon: Iconsax.camera,
            color: const Color(0xFF2E7D32),
            onTap: _isProcessing ? null : _detectDiseaseFromCamera,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Gallery',
            icon: Iconsax.gallery,
            color: const Color(0xFF388E3C),
            onTap: _isProcessing ? null : _pickFromGallery,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MODEL CARDS 2×2 GRID
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildModelGrid() {
    // Define the 4 models we always show (cards filled from _modelResults when available)
    final List<Map<String, dynamic>> models = [
      {'key': 'mobilenet', 'label': 'MobileNet'},
      {'key': 'efficientnet', 'label': 'EfficientNet'},
      {'key': 'cnn', 'label': 'CNN'},
      {'key': 'ensemble', 'label': 'Ensemble'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: models.map((m) {
        final key = m['key'] as String;
        final label = m['label'] as String;

        // Try to find matching data regardless of case
        MapEntry<String, dynamic>? matchedEntry;
        if (_modelResults != null) {
          for (final entry in _modelResults!.entries) {
            if (entry.key.toLowerCase().contains(key.toLowerCase()) ||
                key.toLowerCase().contains(entry.key.toLowerCase())) {
              matchedEntry = entry;
              break;
            }
          }
        }

        final hasData = matchedEntry != null;
        final confidence = hasData
            ? (matchedEntry.value['confidence'] as num).toDouble()
            : null;
        final diseaseName = hasData
            ? (matchedEntry.value['disease_name'] as String)
            : null;

        return GestureDetector(
          onTap: hasData
              ? () async {
                  setState(() => _isProcessing = true);
                  try {
                    final adviceRes = await ApiService.getDynamicAdvice(
                        diseaseName!, confidence!.toString());
                    if (adviceRes['success'] == true) {
                      final advice = adviceRes['groq_advice'];
                      setState(() {
                        _detectedDisease = advice['disease_name'];
                        _confidence = confidence;
                        _solutions = List<String>.from(advice['solutions'] ?? []);
                        _pesticide = advice['pesticide'];
                        _dosage = advice['dosage'];
                        _frequency = advice['frequency'];
                        _description = advice['description'];
                        _isProcessing = false;
                      });
                    } else {
                      setState(() => _isProcessing = false);
                      _showErrorSnackBar('Failed to fetch specific advice');
                    }
                  } catch (e) {
                    setState(() => _isProcessing = false);
                    _showErrorSnackBar('Error: $e');
                  }
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasData
                    ? const Color(0xFF81C784)
                    : const Color(0xFFCFD8DC),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    if (hasData)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${confidence!.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasData) ...[
                  Text(
                    diseaseName!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  LinearProgressIndicator(
                    value: (confidence! / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 5,
                  ),
                ] else
                  Text(
                    'Awaiting scan',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // COMPARISON / HISTORY ROW
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildComparisonHistoryRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _modelResults != null
                ? () => _showComparisonSheet(context)
                : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2E7D32), width: 1.2),
              foregroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledForegroundColor: Colors.grey.shade400,
            ),
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: Text(
              'Comparison',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showHistoryBottomSheet(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2E7D32), width: 1.2),
              foregroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.history, size: 18),
            label: Text(
              'History',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // RESULT DETAILS (description, solutions, pesticide)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildResultDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA5D6A7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Disease name + confidence
          Row(
            children: [
              Expanded(
                child: Text(
                  _detectedDisease ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: Text(
                  '${_confidence?.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ),
            ],
          ),

          if (_description != null) ...[
            const SizedBox(height: 12),
            Text(
              'Description',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Text(
              _description!,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade700, height: 1.5),
            ),
          ],

          if (_solutions != null && _solutions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Recommended Solutions',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            ..._solutions!.map((solution) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 5, right: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          solution,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (_pesticide != null && _pesticide != 'None') ...[
            const SizedBox(height: 14),
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
                  Text('Product: $_pesticide',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.orange.shade800)),
                  if (_dosage != null && _dosage != 'N/A')
                    Text('Dosage: $_dosage',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.orange.shade800)),
                  if (_frequency != null && _frequency != 'N/A')
                    Text('Frequency: $_frequency',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.orange.shade800)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DOWNLOAD BUTTON (full-width, always at bottom)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _detectedDisease != null ? _downloadImage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        icon: const Icon(Iconsax.document_download, size: 20),
        label: Text(
          'Download',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ERROR BANNER
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Iconsax.warning_2, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(
                  color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // COMPARISON BOTTOM SHEET
  // ────────────────────────────────────────────────────────────────────────────
  void _showComparisonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Model Comparison',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: _modelResults!.entries.map((entry) {
                    final modelName = entry.key;
                    final data = entry.value;
                    final double conf = (data['confidence'] as num).toDouble();
                    final String diseaseName = data['disease_name'];
                    
                    final metrics = data['metrics'] as Map<String, dynamic>?;
                    final isBest = _instanceAnalysis?['best_model'] == modelName;
                    final isUnreliable = (_instanceAnalysis?['unreliable_models'] as List<dynamic>?)?.contains(modelName) ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBest ? const Color(0xFFE8F5E9) : (isUnreliable ? Colors.red.shade50 : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isBest ? const Color(0xFF81C784) : (isUnreliable ? Colors.red.shade200 : Colors.grey.shade200),
                          width: isBest ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    modelName.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isUnreliable ? Colors.red.shade800 : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                  if (isBest) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  if (isUnreliable) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                                  ],
                                ],
                              ),
                              Text(
                                '${conf.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(diseaseName, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                          
                          if (metrics != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricItem('Accuracy', '${metrics['accuracy']}%'),
                                _buildMetricItem('Precision', '${metrics['precision']}%'),
                                _buildMetricItem('Recall', '${metrics['recall']}%'),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (conf / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            color: isUnreliable ? Colors.red.shade300 : const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                          if (isUnreliable)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '⚠️ This model might be unreliable for this specific image.',
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.poppins(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HISTORY BOTTOM SHEET
  // ────────────────────────────────────────────────────────────────────────────
  void _showHistoryBottomSheet(BuildContext context) async {
    final history = await DiseaseHistoryService.getLocalHistory();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detection History',
                    style: GoogleFonts.poppins(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),
              history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50.0),
                        child: Text(
                          'No history found.\nAnalyses you run will appear here even offline.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        controller: controller,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          final solutions =
                              item['solutions'] as List<dynamic>? ?? [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['disease'] ?? 'Unknown',
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: const Color(0xFF1B5E20)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${item['confidence']}%',
                                        style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['synced'] == true
                                      ? 'Synced to Cloud • ${item['date'].toString().split('T')[0]}'
                                      : 'Offline Mode • ${item['date'].toString().split('T')[0]}',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                                if (solutions.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text('Solutions:',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    solutions.isNotEmpty
                                        ? solutions.first.toString()
                                        : 'No solutions',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                ]
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// REUSABLE ACTION BUTTON WIDGET
// ────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        disabledBackgroundColor: Colors.grey.shade400,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 1,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}