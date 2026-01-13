import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5001';
  // Android Emulator: http://10.0.2.2:5001
  // Real device: Use your PC IP address

  // =========================
  // COMMON HEADERS
  // =========================
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

  // =========================
  // LOGIN API
  // =========================
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

  // =========================
  // SIGNUP API
  // =========================
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
          'message': 'Registration successful',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Registration failed',
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

  // =========================
  // FORGOT PASSWORD
  // =========================
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
          'message':
              responseData['message'] ?? 'Password reset link sent to email',
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

  // =========================
  // VERIFY RESET TOKEN
  // =========================
  static Future<Map<String, dynamic>> verifyResetToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-reset-token'),
        headers: getHeaders(),
        body: jsonEncode({
          'token': token,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'data': responseData,
          'message': responseData['message'] ?? 'Token verified successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Invalid or expired token',
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

  // =========================
  // RESET PASSWORD WITH TOKEN
  // =========================
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: getHeaders(),
        body: jsonEncode({
          'token': token,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'status': 'ok',
          'data': responseData,
          'message': responseData['message'] ?? 'Password reset successful',
        };
      } else {
        return {
          'status': 'error',
          'message': responseData['message'] ?? 'Failed to reset password',
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

  // =========================
  // SAVE TOKEN
  // =========================
  static Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setBool('is_logged_in', true);
      print('Token saved successfully');
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  // =========================
  // GET TOKEN
  // =========================
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // =========================
  // CHECK LOGIN STATUS
  // =========================
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      return token != null && isLoggedIn;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // =========================
  // LOGOUT
  // =========================
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('is_logged_in');
      print('Logged out successfully');
    } catch (e) {
      print('Error logging out: $e');
    }
  }
}
