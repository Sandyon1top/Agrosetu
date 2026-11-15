import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class EnvConfig {
  // ── Production URLs (set at build time via --dart-define) ──
  // For Render deployment:
  //   flutter build web --dart-define=NODE_URL=https://agrosetu-backend.onrender.com
  //                     --dart-define=FLASK_URL=https://agrosetu-ml.onrender.com

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

  static String get nodeBaseUrl {
    const envUrl = String.fromEnvironment('NODE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'http://$apiHost:$nodePort';
  }

  static String get flaskBaseUrl {
    const envUrl = String.fromEnvironment('FLASK_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'http://$apiHost:$flaskPort';
  }
}
