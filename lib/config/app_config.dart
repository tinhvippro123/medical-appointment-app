import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (kIsWeb) return 'http://localhost:5041';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5041';
    }

    return 'http://localhost:5041';
  }
}
