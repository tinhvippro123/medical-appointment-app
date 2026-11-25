import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../helpers/api_exception.dart';
import '../helpers/session_helper.dart';
import '../models/auth_models.dart';
import '../models/user_role_models.dart';

class AuthRepository {
  AuthRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
  }) : _client = client ?? http.Client(),
       baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _token = token ?? SessionHepler.getToken;

  final http.Client _client;
  final String baseUrl;
  final Future<String?> Function() _token;

  Future<SessionUser?> loginRequest(LoginRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode == 200 && data is Map && data['token'] is String) {
        final jwt = data['token'] as String;
        await SessionHepler.saveToken(jwt);
        return SessionHepler.decodeToken(jwt);
      }

      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Đăng nhập không thành công',
        ),
        errorCode: data is Map ? data['errorCode'] as String? : null,
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Kết nối quá thời gian. Vui lòng thử lại.');
    } catch (_) {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
  }

  Future<void> registerRequest(RegisterRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      final data = _tryDecode(response.bodyBytes);
      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Đăng ký không thành công.',
        ),
        errorCode: data is Map ? data['errorCode'] as String? : null,
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Kết nối quá thời gian. Vui lòng thử lại.');
    } catch (_) {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
  }

  Future<void> changePasswordRequest(ChangePasswordRequest request) async {
    final jwt = await _token();
    if (jwt == null || jwt.isEmpty) {
      throw const ApiException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );
    }

    try {
      final response = await _client
          .put(
            Uri.parse('$baseUrl/api/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      final data = _tryDecode(response.bodyBytes);
      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Đổi mật khẩu không thành công.',
        ),
        errorCode: data is Map ? data['errorCode'] as String? : null,
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Kết nối quá thời gian. Vui lòng thử lại.');
    } catch (_) {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
  }

  Future<void> logoutRequest({bool clearRemoteCart = true}) async {
    try {
      final jwt = await _token();
      if (jwt != null && jwt.isNotEmpty) {
        await _client
            .post(
              Uri.parse('$baseUrl/api/auth/logout'),
              headers: {'Authorization': 'Bearer $jwt'},
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Logout cuc bo van phai tiep tuc du server khong phan hoi.
    } finally {
      await SessionHepler.clear(clearRemoteCart: clearRemoteCart);
    }
  }

  dynamic _tryDecode(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      return null;
    }
  }

  static Future<SessionUser?> login(LoginRequest request) =>
      AuthRepository().loginRequest(request);

  static Future<void> register(RegisterRequest request) =>
      AuthRepository().registerRequest(request);

  static Future<void> changePassword(ChangePasswordRequest request) =>
      AuthRepository().changePasswordRequest(request);

  static Future<void> logout({bool clearRemoteCart = true}) =>
      AuthRepository().logoutRequest(clearRemoteCart: clearRemoteCart);
}
