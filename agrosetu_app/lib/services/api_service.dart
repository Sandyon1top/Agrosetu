import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Backend selection enum for easy switching between targets.
enum BackendTarget { localhost, emulator, ngrok, custom }

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5001';

  // NOTE: `flaskBaseUrl` is configurable at runtime so you can switch
  // easily between local, emulator and ngrok when testing on devices.
  // Default (local machine running Flask):
  static String flaskBaseUrl = 'http://127.0.0.1:8000';

  // Helper to change target backend quickly from code:
  static void setBackendTarget(BackendTarget target, {String? ngrokUrl, String? customUrl}) {
    switch (target) {
      case BackendTarget.localhost:
        flaskBaseUrl = 'http://127.0.0.1:8000';
        break;
      case BackendTarget.emulator:
        // Android emulator special host mapping
        flaskBaseUrl = 'http://10.0.2.2:8000';
        break;
      case BackendTarget.ngrok:
        if (ngrokUrl != null && ngrokUrl.isNotEmpty) {
          flaskBaseUrl = ngrokUrl;
        }
        break;
      case BackendTarget.custom:
        if (customUrl != null && customUrl.isNotEmpty) {
          flaskBaseUrl = customUrl;
        }
        break;
    }
  }

  // Common headers
  static Map<String, String> getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Login API
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        if (responseData['token'] != null) {
          await _saveToken(responseData['token']);
        }
        return {
          'status': 'ok',
          'data': responseData,
          'message': responseData['message'] ?? 'Login successful',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Login failed',
          'error': responseData,
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }
  
  // Signup API
  static Future<Map<String, dynamic>> signup(
      String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: getHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'status': 'ok',
          'data': responseData,
          'message': responseData['message'] ?? 'Registration successful',
        };
      } else {
        final errorMessage = responseData['message'] ?? 'Registration failed';
        final errors = responseData['errors'];
        
        return {
          'status': 'error',
          'message': errorMessage,
          'errors': errors,
          'error': responseData,
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  // Verify OTP API
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: getHeaders(),
        body: jsonEncode({
          'identity': email,
          'otp': otp,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'ok',
          'message': responseData['message'] ?? 'OTP verified successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  // Resend OTP API
  static Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/resend-otp'),
        headers: getHeaders(),
        body: jsonEncode({
          'identity': email,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'ok',
          'message': responseData['message'] ?? 'OTP resent successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to resend OTP',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }
  
  // Forgot Password API
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: getHeaders(),
        body: jsonEncode({
          'email': email,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'data': responseData,
          'message': responseData['message'] ?? 'Password reset link sent to your email',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to send reset email',
          'error': responseData,
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }
  
  static Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setBool('is_logged_in', true);
      debugPrint('Token saved successfully');
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }
  
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }
  
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      return token != null && isLoggedIn;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }
  
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('is_logged_in');
      debugPrint('Logged out successfully');
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  // ====== COMMUNITY POST APIS ======
  
  static Future<Map<String, dynamic>> getPosts(String category) async {
    try {
      final url = category == 'All' 
          ? '$baseUrl/api/community/posts'
          : '$baseUrl/api/community/posts?category=$category';
      
      final response = await http.get(
        Uri.parse(url),
        headers: getHeaders(),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'posts': responseData['posts'] ?? [],
          'message': 'Posts fetched successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to fetch posts',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getPostById(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/community/post-detail/$postId'),
        headers: getHeaders(),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'post': responseData['post'],
          'message': 'Post fetched successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to fetch post',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String description,
    required String category,
    required Map<String, dynamic> author,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: getHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          'author': author,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'ok',
          'post': responseData['post'],
          'message': responseData['message'] ?? 'Post created successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to create post',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> likePost({
    required String postId,
    required String userId,
    required String userName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'userName': userName,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'likes': responseData['likes'],
          'liked': responseData['liked'],
          'message': responseData['message'] ?? 'Like toggled',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to like post',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String userEmail,
    required String text,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/comments'),
        headers: getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'text': text,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'comment': responseData['comment'],
          'message': responseData['message'] ?? 'Comment added',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to add comment',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> deletePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/community/posts/$postId'),
        headers: getHeaders(),
        body: jsonEncode({
          'userId': userId,
        }),
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'message': responseData['message'] ?? 'Post deleted',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to delete post',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/password-reset/request'),
        headers: getHeaders(),
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 10));

      try {
        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'status': 'ok',
            'data': responseData,
            'message': responseData['message'] ?? 'Reset code sent to email',
          };
        } else {
          return {
            'status': 'error',
            'message': responseData['message'] ?? 'Failed to send reset code',
          };
        }
      } catch (parseError) {
        debugPrint('[ApiService] JSON Parse Error: $parseError');
        return {
          'status': 'error',
          'message': 'Server error: Invalid response format',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error: No internet connection. Make sure backend server is running on $baseUrl',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/password-reset/verify'),
        headers: getHeaders(),
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      try {
        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'status': 'ok',
            'data': responseData,
            'message': responseData['message'] ?? 'Password reset successfully',
          };
        } else {
          return {
            'status': 'error',
            'message': responseData['message'] ?? 'Failed to reset password',
            'errors': responseData['errors'],
          };
        }
      } catch (parseError) {
        debugPrint('[ApiService] JSON Parse Error: $parseError');
        return {
          'status': 'error',
          'message': 'Server error: Invalid response format',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error: No internet connection. Make sure backend server is running on $baseUrl',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }

  // ====== DISEASE DETECTION API ======

  static Future<Map<String, dynamic>> predictDiseaseFromImage(
      String imagePath, {String endpoint = '/predict'}) async {
    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        return {
          'status': 'error',
          'message': 'Image file not found at $imagePath',
        };
      }

      final imageBytes = await imageFile.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$flaskBaseUrl$endpoint'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'disease_detection.jpg',
        ),
      );

      debugPrint('[Flutter] Sending prediction request to $flaskBaseUrl$endpoint');

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );

      final response = await http.Response.fromStream(streamResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Handle both simple prediction and compare prediction results
        return {
          'status': 'ok',
          ...responseData 
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['error'] ?? 'Failed to predict disease',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error: Flask server not running on $flaskBaseUrl',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> predictDiseaseFromImageBytes(
      Uint8List imageBytes, {String endpoint = '/predict'}) async {
    try {
      if (imageBytes.isEmpty) {
        return {'status': 'error', 'message': 'Image is empty'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$flaskBaseUrl$endpoint'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'disease_detection.jpg',
        ),
      );

      debugPrint('[Flutter] Sending prediction request to $flaskBaseUrl$endpoint');

      final streamResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );

      final response = await http.Response.fromStream(streamResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          ...responseData
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['error'] ?? 'Failed to predict disease',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error: Flask server not running on $flaskBaseUrl',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getFlaskHealthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$flaskBaseUrl/health'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': 'ok',
          'server_status': data['status'],
          'models_loaded': data['models_loaded'],
        };
      } else {
        return {
          'status': 'error',
          'message': 'Flask server returned error',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Flask server not reachable: $e',
      };
    }
  }

  // Get dynamic AI advice for a specific disease
  static Future<Map<String, dynamic>> getDynamicAdvice(String disease, String confidence) async {
    try {
      final response = await http.post(
        Uri.parse('$flaskBaseUrl/predict/advice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'disease_name': disease,
          'confidence': confidence,
        }),
      ).timeout(const Duration(seconds: 30));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'groq_advice': responseData['groq_advice']
        };
      } else {
        return {'success': false, 'message': responseData['error'] ?? 'Failed to fetch advice'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Sync disease history to MongoDB
  static Future<Map<String, dynamic>> syncDiseaseHistory(String userId, List<dynamic> detections) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/disease-history/sync'),
        headers: getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'detections': detections,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'status': 'ok', 'message': 'History synced'};
      } else {
        return {'status': 'error', 'message': responseData['message'] ?? 'Sync failed'};
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Sync error: $e'};
    }
  }
}