import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSpeaking = false;
  String _recognizedText = '';
  String _answerText = '';
  String _audioBase64 = '';
  String _partialText = '';

  late AnimationController _animController;
  late Animation<double> _pulseAnim;

  bool _submitInProgress = false;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _setupTts();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[STT] Error: ${error.errorMsg}');
          if (mounted) {
            setState(() => _isListening = false);
            if (error.errorMsg != 'error_no_match') {
              _showError('${'voice.speech_error'.tr}${error.errorMsg}');
            }
          }
        },
        onStatus: (status) {
          debugPrint('[STT] Status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            if (_recognizedText.isNotEmpty && !_isLoading && !_submitInProgress) {
              _submitQuery(_recognizedText);
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[STT] Init failed: $e');
      if (mounted) _showError('voice.speech_unavailable'.tr);
    }
  }

  void _setupTts() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isSpeaking = state.playing && state.processingState != ProcessingState.completed;
        });
      }
    });
  }

  Future<void> _pickAndUploadAudio() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isLoading = true;
        _recognizedText = 'voice.processing_audio'.tr;
        _answerText = '';
        _audioBase64 = '';
      });

      final uri = Uri.parse('${ApiService.baseUrl}/api/voice/audio-query');
      final token = await ApiService.getToken();
      var request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final file = result.files.first;
      
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        throw Exception('disease.cant_read_file'.tr);
      }
      
      request.fields['userId'] = 'web_user';

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recognizedText = data['recognizedText'] ?? data['transcript'] ?? 'voice.audio_received'.tr;
          _answerText = data['answer'] ?? '';
          _audioBase64 = data['audioBase64'] ?? '';
        });
        if (_audioBase64.isNotEmpty) await _speakAnswer();
      } else {
        _showError('${'voice.upload_failed'.tr}${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Audio Upload Error: $e");
      _showError('${'voice.upload_error'.tr}$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Live mic recording → backend Whisper. iOS 26 does not ship a Nepali
  // speech recognizer, so we bypass on-device STT entirely and let Whisper
  // (which handles Nepali natively) do the transcription on the server.
  Future<void> _startListening() async {
    setState(() {
      _recognizedText = '';
      _answerText = '';
      _audioBase64 = '';
      _partialText = '';
      _submitInProgress = false;
    });
    _silenceTimer?.cancel();

    try {
      if (!await _audioRecorder.hasPermission()) {
        _showError('voice.mic_denied'.tr);
        return;
      }
      final dir = await getTemporaryDirectory();
      // WAV (PCM) — Whisper reads it even if the file isn't perfectly
      // finalized. AAC/M4A was failing on backend with "moov atom not found"
      // because the container metadata is written at the END of recording,
      // and any abrupt stop left the file unreadable to ffmpeg.
      _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, numChannels: 1, sampleRate: 16000),
        path: _recordingPath!,
      );
      setState(() {
        _isListening = true;
        _recognizedText = 'voice.recording'.tr;
      });

      // Hard stop after 30 s in case user forgets to tap stop.
      _silenceTimer = Timer(const Duration(seconds: 30), () {
        if (_isListening && mounted) _stopListening();
      });
    } catch (e) {
      _showError('${'voice.cant_record'.tr}$e');
    }
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    if (!await _audioRecorder.isRecording()) return;
    final path = await _audioRecorder.stop();
    setState(() => _isListening = false);
    if (path == null) return;
    await _uploadRecording(path);
  }

  Future<void> _uploadRecording(String filePath) async {
    setState(() {
      _isLoading = true;
      _recognizedText = 'voice.processing_audio'.tr;
      _answerText = '';
      _audioBase64 = '';
    });
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/voice/audio-query');
      final token = await ApiService.getToken();
      final request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('audio', filePath, filename: 'rec.m4a'));
      request.fields['userId'] = 'mobile_user';
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        _showError('${'voice.server_error'.tr}${response.statusCode}');
        return;
      }
      final data = jsonDecode(response.body);
      setState(() {
        _recognizedText = data['recognizedText'] ?? data['transcript'] ?? '';
        _answerText = data['answer'] ?? '';
        _audioBase64 = data['audioBase64'] ?? '';
      });
      if (_audioBase64.isNotEmpty) await _speakAnswer();
    } catch (e) {
      _showError('${'voice.cant_get_answer'.tr}$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      if (result.finalResult) {
        _recognizedText = result.recognizedWords;
        _partialText = '';
      } else {
        _partialText = result.recognizedWords;
      }
    });

    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 4), () {
      if (_isListening && mounted) {
        _stopListening();
      }
    });
  }

  Future<void> _submitQuery(String query) async {
    if (query.trim().isEmpty) return;
    _submitInProgress = true;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/voice/query');
      final token = await ApiService.getToken();

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'userId': 'web_user',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        _showError('${'voice.server_error'.tr}${response.statusCode}');
        return;
      }

      final result = jsonDecode(response.body);
      if (result['status'] == 'ok') {
        final answer = result['answer'] ?? '';
        final audioBase64 = result['audioBase64'] ?? '';
        setState(() {
          _answerText = answer;
          _audioBase64 = audioBase64;
        });
        if (_audioBase64.isNotEmpty) await _speakAnswer();
      } else {
        _showError(result['message'] ?? result['error'] ?? 'voice.server_error'.tr);
      }
    } catch (e) {
      _showError('${'voice.failed_answer'.tr}$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _submitInProgress = false;
      }
    }
  }

  Future<void> _speakAnswer() async {
    if (_audioBase64.isEmpty) return;
    try {
      setState(() => _isSpeaking = true);
      await _audioPlayer.setVolume(1.0);

      final bytes = base64Decode(_audioBase64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes, flush: true);
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('[VoiceAssistant] TTS error: $e');
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _stopSpeaking() async {
    await _audioPlayer.stop();
    setState(() => _isSpeaking = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    final lower = message.toLowerCase();
    final isOffline = lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('network error') ||
        lower.contains('no internet') ||
        lower.contains('connection') ||
        lower.contains('unreachable');

    final shown = isOffline
        ? 'voice.no_internet'.tr
        : message;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(shown, style: GoogleFonts.poppins()),
        backgroundColor:
            isOffline ? Colors.orange.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isOffline ? 4 : 3),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _recognizedText = '';
      _answerText = '';
      _audioBase64 = '';
      _partialText = '';
      _submitInProgress = false;
    });
    _audioPlayer.stop();
    _speechToText.stop();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _animController.dispose();
    _speechToText.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _recognizedText.isNotEmpty || _answerText.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'voice.title'.tr,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          if (hasResult)
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _clearResults),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'voice.tip'.tr,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1B5E20), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            GestureDetector(
              onTap: _isLoading ? null : () async {
                if (_isListening) {
                  await _stopListening();
                } else {
                  await _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Transform.scale(scale: _isListening ? _pulseAnim.value : 1.0, child: child),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : _isLoading ? Colors.grey : const Color(0xFF2E7D32),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : const Color(0xFF2E7D32)).withValues(alpha: 0.4),
                        blurRadius: 20, spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 48),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              _isLoading ? 'voice.processing'.tr : _isListening ? 'voice.listening'.tr : 'voice.tap_mic'.tr,
              style: GoogleFonts.poppins(fontSize: 15, color: _isListening ? Colors.red : Colors.grey.shade700, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 25),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickAndUploadAudio,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), // ✅ Fixed: Correct Shape
              ),
              icon: const Icon(Icons.upload_file, color: Color(0xFF2E7D32)),
              label: Text(
                'voice.upload_audio'.tr,
                style: GoogleFonts.poppins(color: const Color(0xFF2E7D32), fontWeight: FontWeight.w600),
              ),
            ),

            if (_partialText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text(_partialText, style: GoogleFonts.poppins(fontSize: 14, color: Colors.blue.shade800, fontStyle: FontStyle.italic)),
              ),
            ],

            const SizedBox(height: 30),

            if (!hasResult && !_isListening && !_isLoading)
              Column(
                children: [
                  Text('voice.example_prompts'.tr, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                    children: [
                      _buildExampleChip('voice.example_potato'.tr),
                      _buildExampleChip('voice.example_corn'.tr),
                    ],
                  ),
                ],
              ),

            if (hasResult) ...[
              if (_recognizedText.isNotEmpty) ...[
                _buildResultCard(title: 'voice.message_label'.tr, content: _recognizedText, color: Colors.blue.shade50, borderColor: Colors.blue.shade200, textColor: Colors.blue.shade900),
                const SizedBox(height: 16),
              ],
              if (_answerText.isNotEmpty) ...[
                _buildResultCard(title: 'voice.answer_label'.tr, content: _answerText, color: const Color(0xFF2E7D32).withValues(alpha: 0.06), borderColor: const Color(0xFF2E7D32).withValues(alpha: 0.3), textColor: const Color(0xFF1B5E20)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSpeaking ? _stopSpeaking : _speakAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpeaking ? Colors.orange : const Color(0xFF2E7D32), 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)) // ✅ Fixed: Correct Shape
                    ),
                    icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, size: 22),
                    label: Text(_isSpeaking ? 'voice.stop'.tr : 'voice.listen_answer'.tr, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return GestureDetector(
      onTap: () {
        setState(() { _recognizedText = text; _answerText = ''; _audioBase64 = ''; _submitInProgress = false; });
        _submitQuery(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.4))),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildResultCard({required String title, required String content, required Color color, required Color borderColor, required Color textColor}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 10),
        Text(content, style: GoogleFonts.poppins(fontSize: 15, color: textColor, height: 1.6)),
      ]),
    );
  }
}