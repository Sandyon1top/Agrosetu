import 'package:flutter/foundation.dart';
import 'dart:io';

class EnvConfig {
  static String get apiHost {
    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) return envHost;
    // Android emulator uses 10.0.2.2 to reach the host Mac
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    // macOS desktop and Chrome web — backends are on the same machine
    if (kIsWeb || (!kIsWeb && Platform.isMacOS)) return 'localhost';
    // iOS physical devices use the Mac's local IP
    return '192.168.101.2';
  }

  static const String nodePort =
      String.fromEnvironment('NODE_PORT', defaultValue: '5001');

  static const String flaskPort =
      String.fromEnvironment('FLASK_PORT', defaultValue: '8000');

  static String get nodeBaseUrl => 'http://$apiHost:$nodePort';
  static String get flaskBaseUrl => 'http://$apiHost:$flaskPort';
}
