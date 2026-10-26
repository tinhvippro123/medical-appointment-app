import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:medical_appointment_app/config/app_config.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/models/auth_models.dart';

class AuthRepository {
  static final String _baseUrl = '${AppConfig.baseUrl}/api/auth';

  static Future<void> login(LoginRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      final token = data['token'] as String;
      await SessionHepler.saveToken(token);
    } else {
      final message = data['message'] ?? 'Đăng nhập không thành công';
      throw Exception(message);
    }
  }

  static Future<void> register(RegisterRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final message = data['message'] ?? 'Đăng ký không thành công.';
      throw Exception(message);
    }
  }
}
