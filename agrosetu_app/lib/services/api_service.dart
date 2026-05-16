import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'env_config.dart';

/// Backend selection enum for easy switching between targets.
enum BackendTarget { localhost, emulator, ngrok, custom }

class ApiService {
  static String baseUrl = EnvConfig.nodeBaseUrl;

  // NOTE: `flaskBaseUrl` is configurable at runtime so you can switch
  // easily between local, emulator and ngrok when testing on devices.
  // Default (local machine running Flask):
  static String flaskBaseUrl = EnvConfig.flaskBaseUrl;

  // Helper to change target backend quickly from code:
  static void setBackendTarget(BackendTarget target, {String? ngrokUrl, String? customUrl}) {
    switch (target) {
      case BackendTarget.localhost:
        flaskBaseUrl = EnvConfig.flaskBaseUrl;
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

  /// Auto-attaches `Authorization: Bearer <token>` from stored user session.
  /// Use this for any endpoint protected by `authenticateToken` middleware
  /// on the Node backend.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return getHeaders(token: token);
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
      ).timeout(const Duration(seconds: 15));
      
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

  // Google Login API
  static Future<Map<String, dynamic>> googleLogin(String idToken) async {
    try {
      debugPrint('[ApiService] Posting Google ID token to $baseUrl/api/auth/google');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: getHeaders(),
        body: jsonEncode({'idToken': idToken}),
      ).timeout(const Duration(seconds: 15));

      try {
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200) {
          if (responseData['data']?['token'] != null) {
            await _saveToken(responseData['data']['token']);
          }
          return {
            'status': 'ok',
            'data': responseData['data'],
            'message': responseData['message'] ?? 'Google login successful',
          };
        } else {
          return {
            'status': 'error',
            'message': responseData['message'] ?? 'Google login failed',
            'error': responseData,
          };
        }
      } catch (parseError) {
        debugPrint('[ApiService] Google login JSON Parse Error: $parseError');
        return {
          'status': 'error',
          'message': 'Server error: Invalid response format',
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'message': 'Network error: Cannot reach backend at $baseUrl. '
            'Check that your Flask server is running and reachable from your device.',
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'Google login timed out. Backend may be slow or unreachable.',
      };
    } catch (e) {
      debugPrint('[ApiService] Google login error: $e');
      return {'status': 'error', 'message': 'Network error: $e'};
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
      ).timeout(const Duration(seconds: 15));
      
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
      ).timeout(const Duration(seconds: 15));
      
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
      ).timeout(const Duration(seconds: 15));
      
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
      ).timeout(const Duration(seconds: 15));
      
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
      ).timeout(const Duration(seconds: 15));

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
      ).timeout(const Duration(seconds: 15));
      
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
    String? imageData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: await getAuthHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          'author': author,
          'image_data': imageData,
        }),
      ).timeout(const Duration(seconds: 30));
      
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

  // Search users API
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search?query=$query'),
        headers: getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'users': responseData['users'],
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to search users',
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
      ).timeout(const Duration(seconds: 10));
      
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
      ).timeout(const Duration(seconds: 15));
      
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
        headers: await getAuthHeaders(),
        body: jsonEncode({
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 15));
      
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

  // Grad-CAM Visualization API
  static Future<Map<String, dynamic>> predictVisualization(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$flaskBaseUrl/predict/visualize'),
      );
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'leaf_scan.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'heatmap_base64': responseData['heatmap_base64'],
          'model_used': responseData['model_used'],
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Visualization failed',
        };
      }
    } catch (e) {
      debugPrint('[API] Visualization error: $e');
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

  // ====== USER PROFILE / SETTINGS / SUPPORT ======

  static Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? location,
    String? farmSize,
    List<String>? mainCrops,
  }) async {
    try {
      final token = await getToken();
      final body = <String, dynamic>{'userId': userId};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (location != null) body['location'] = location;
      if (farmSize != null) body['farmSize'] = farmSize;
      if (mainCrops != null) body['mainCrops'] = mainCrops;

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/user/update'),
            headers: getHeaders(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'user': data['user'], 'message': data['message'] ?? 'Profile updated'};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to update profile'};
    } on SocketException {
      return {'status': 'error', 'message': 'No internet connection'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/user/settings/$userId'), headers: await getAuthHeaders())
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'preferences': data['preferences'] ?? {}};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to load settings'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateUserSettings({
    required String userId,
    String? language,
    bool? notificationsEnabled,
    bool? profileVisibility,
    bool? activityLogging,
    bool? locationServicesEnabled,
  }) async {
    try {
      final body = <String, dynamic>{'userId': userId};
      if (language != null) body['language'] = language;
      if (notificationsEnabled != null) body['notificationsEnabled'] = notificationsEnabled;
      if (profileVisibility != null) body['profileVisibility'] = profileVisibility;
      if (activityLogging != null) body['activityLogging'] = activityLogging;
      if (locationServicesEnabled != null) body['locationServicesEnabled'] = locationServicesEnabled;

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/user/settings'),
            headers: await getAuthHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'preferences': data['preferences'] ?? {}};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to update settings'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/change-password'),
            headers: await getAuthHeaders(),
            body: jsonEncode({
              'userId': userId,
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'message': data['message'] ?? 'Password changed'};
      }
      return {
        'status': 'error',
        'message': data['message'] ?? 'Failed to change password',
        'errors': data['errors'],
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deactivateAccount(String userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/user/deactivate'),
            headers: await getAuthHeaders(),
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'message': data['message'] ?? 'Account deleted'};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to delete account'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendSupportMessage({
    String? userId,
    String? userName,
    String? userEmail,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/contact/send-message'),
            headers: getHeaders(),
            body: jsonEncode({
              'userId': userId,
              'userName': userName,
              'userEmail': userEmail,
              'subject': subject,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'message': data['message'] ?? 'Message sent'};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to send message'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/user/export-data/$userId'),
            headers: await getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'status': 'ok', 'data': data};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Failed to export data'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // ====== ADMIN PANEL APIS ======

  static Future<Map<String, dynamic>> adminLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/login'),
        headers: getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'ok') {
        return {'status': 'ok', 'token': data['token'], 'user': data['user']};
      }
      return {'status': 'error', 'message': data['message'] ?? 'Admin login failed'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> adminGetStats() async {
    return _adminGet('/api/admin/stats');
  }

  static Future<Map<String, dynamic>> adminGetTimeseries({int days = 30}) async {
    return _adminGet('/api/admin/detections-timeseries?days=$days');
  }

  static Future<Map<String, dynamic>> adminGetUsers({int page = 1, int limit = 20, String search = ''}) async {
    final encodedSearch = Uri.encodeQueryComponent(search);
    return _adminGet('/api/admin/users?page=$page&limit=$limit&search=$encodedSearch');
  }

  static Future<Map<String, dynamic>> adminSuspendUser(String userId) async {
    return _adminPost('/api/admin/users/$userId/suspend');
  }

  static Future<Map<String, dynamic>> adminActivateUser(String userId) async {
    return _adminPost('/api/admin/users/$userId/activate');
  }

  static Future<Map<String, dynamic>> adminDeleteUser(String userId) async {
    return _adminDelete('/api/admin/users/$userId');
  }

  static Future<Map<String, dynamic>> adminGetPosts({int page = 1, int limit = 15}) async {
    return _adminGet('/api/admin/posts?page=$page&limit=$limit');
  }

  static Future<Map<String, dynamic>> adminDeletePost(String postId) async {
    return _adminDelete('/api/admin/posts/$postId');
  }

  static Future<Map<String, dynamic>> adminPinPost(String postId, bool pinned) async {
    return _adminPost('/api/admin/posts/$postId/pin', body: {'pinned': pinned});
  }

  static Future<Map<String, dynamic>> adminGetDetections({int page = 1, int limit = 25}) async {
    return _adminGet('/api/admin/detections?page=$page&limit=$limit');
  }

  static Future<Map<String, dynamic>> _adminGet(String path) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: getHeaders(token: token),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'status': 'ok', ...data};
      return {'status': 'error', 'code': response.statusCode, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _adminPost(String path, {Map<String, dynamic>? body}) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: getHeaders(token: token),
        body: body == null ? null : jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'status': 'ok', ...data};
      return {'status': 'error', 'code': response.statusCode, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _adminDelete(String path) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl$path'),
        headers: getHeaders(token: token),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'status': 'ok', ...data};
      return {'status': 'error', 'code': response.statusCode, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  // Sync disease history to MongoDB
  static Future<Map<String, dynamic>> syncDiseaseHistory(String userId, List<dynamic> detections) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/disease-history/sync'),
        headers: await getAuthHeaders(),
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