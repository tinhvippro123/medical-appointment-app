import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http:///localhost:5041';

    if (Platform.isAndroid) return 'http://10.0.2.2:5041';

    return 'http://localhost:5041';
  }
}
