import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class DiseaseDetectionPage extends StatefulWidget {
  const DiseaseDetectionPage({super.key});

  @override
  State<DiseaseDetectionPage> createState() => _DiseaseDetectionPageState();
}

class _DiseaseDetectionPageState extends State<DiseaseDetectionPage> {
  String? _selectedImage;
  bool _isProcessing = false;
  String? _detectedDisease;
  String? _confidence;

  final List<Map<String, dynamic>> _recentDetections = [
    {
      'crop': 'Rice',
      'disease': 'Blast Disease',
      'confidence': '92%',
      'date': 'Today',
      'image': '🌾',
    },
    {
      'crop': 'Tomato',
      'disease': 'Early Blight',
      'confidence': '85%',
      'date': 'Yesterday',
      'image': '🍅',
    },
    {
      'crop': 'Corn',
      'disease': 'Common Rust',
      'confidence': '78%',
      'date': '2 days ago',
      'image': '🌽',
    },
  ];

  void _pickImage() async {
    setState(() {
      _isProcessing = true;
      _selectedImage = '📸';
    });

    // Simulate processing
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isProcessing = false;
      _detectedDisease = 'Rice Blast Disease';
      _confidence = '92%';
    });
  }

  void _uploadImage() async {
    setState(() {
      _isProcessing = true;
      _selectedImage = '📤';
    });

    // Simulate processing
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isProcessing = false;
      _detectedDisease = 'Tomato Early Blight';
      _confidence = '85%';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Upload Section
              _buildUploadSection(),
              
              // Detection Result
              if (_detectedDisease != null) _buildDetectionResult(),
              
              // Recent Detections
              _buildRecentDetections(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crop Disease Detection',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI-powered detection from plant photos',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
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
          Text(
            'Upload Plant Photo',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 20),
          
          // Image Preview
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
                        const Icon(
                          Iconsax.gallery,
                          size: 50,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No image selected',
                          style: GoogleFonts.poppins(
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: _isProcessing
                        ? const CircularProgressIndicator(
                            color: Color(0xFF2E7D32),
                          )
                        : Text(
                            _selectedImage!,
                            style: const TextStyle(fontSize: 80),
                          ),
                  ),
          ),
          
          const SizedBox(height: 20),
          
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Iconsax.camera),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Take Photo',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _uploadImage,
                  style: ElevatedButton