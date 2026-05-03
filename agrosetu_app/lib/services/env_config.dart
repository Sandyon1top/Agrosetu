/// Central host configuration. Override at runtime with:
///   flutter run --dart-define=API_HOST=192.168.x.x
///
/// On Mac, derive the host automatically:
///   flutter run --dart-define=API_HOST=$(ipconfig getifaddr en0)
class EnvConfig {
  static const String apiHost =
      String.fromEnvironment('API_HOST', defaultValue: '192.168.101.6');

  static const String nodePort =
      String.fromEnvironment('NODE_PORT', defaultValue: '5001');

  static const String flaskPort =
      String.fromEnvironment('FLASK_PORT', defaultValue: '8000');

  static String get nodeBaseUrl => 'http://$apiHost:$nodePort';
  static String get flaskBaseUrl => 'http://$apiHost:$flaskPort';
}
