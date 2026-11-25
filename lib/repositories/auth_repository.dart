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

  Future<RegisterResult> registerRequest(RegisterRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data is Map) {
          final msg = (data['message'] ?? data['Message'])?.toString() ??
              'Đăng ký tài khoản thành công.';
          final requiresVerify = data['requiresEmailVerification'] == true;
          final email = data['email'] is String ? data['email'] as String : null;
          final devOtp =
              data['devOtp'] is String ? data['devOtp'] as String : null;
          return RegisterResult(
            message: msg,
            requiresEmailVerification: requiresVerify,
            email: email,
            devOtp: devOtp,
          );
        }
        return const RegisterResult(message: 'Đăng ký tài khoản thành công.');
      }

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

  Future<ForgotPasswordResult> forgotPasswordRequest(
    ForgotPasswordRequest request,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final msg = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Mã OTP đặt lại mật khẩu đã được gửi tới email của bạn.';
        final devOtp = data is Map && data['devOtp'] is String
            ? data['devOtp'] as String
            : null;
        return ForgotPasswordResult(message: msg, devOtp: devOtp);
      }

      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Không thể gửi mã OTP đặt lại mật khẩu.',
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

  Future<void> resetPasswordRequest(ResetPasswordRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/reset-password'),
            headers: {'Content-Type': 'application/json'},
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
          fallback: 'Đặt lại mật khẩu không thành công.',
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

  Future<void> verifyEmailRequest(VerifyEmailRequest request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/verify-email'),
            headers: {'Content-Type': 'application/json'},
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
          fallback: 'Xác thực email không thành công.',
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

  Future<ForgotPasswordResult> resendVerificationOtpRequest(
    String email,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/resend-verify-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final msg = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Đã gửi lại mã OTP xác thực tới email của bạn.';
        final devOtp = data is Map && data['devOtp'] is String
            ? data['devOtp'] as String
            : null;
        return ForgotPasswordResult(message: msg, devOtp: devOtp);
      }

      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Không thể gửi lại mã OTP lúc này.',
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

  Future<void> verifyPasswordRequest(String password) async {
    final jwt = await _token();
    if (jwt == null || jwt.isEmpty) {
      throw const ApiException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth/verify-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode({'password': password}),
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
          fallback: 'Mật khẩu xác thực không chính xác.',
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

  Future<MyProfile> getMyProfileRequest() async {
    final jwt = await _token();
    if (jwt == null || jwt.isEmpty) {
      throw const ApiException(
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
        statusCode: 401,
      );
    }

    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/auth/me'),
            headers: {'Authorization': 'Bearer $jwt'},
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map) {
        return MyProfile.fromJson(Map<String, dynamic>.from(data));
      }

      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Không tải được thông tin cá nhân.',
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

  Future<MyProfile> updateMyProfileRequest(
    UpdateMyProfileRequest request,
  ) async {
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
            Uri.parse('$baseUrl/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));

      final data = _tryDecode(response.bodyBytes);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map) {
        if (data['token'] is String && (data['token'] as String).isNotEmpty) {
          await SessionHepler.saveToken(data['token'] as String);
        }
        final profileMap = data['profile'] is Map
            ? Map<String, dynamic>.from(data['profile'] as Map)
            : Map<String, dynamic>.from(data);
        return MyProfile.fromJson(profileMap);
      }

      throw ApiException(
        parseApiErrorMessage(
          data,
          response.statusCode,
          fallback: 'Cập nhật thông tin không thành công.',
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

  static Future<RegisterResult> register(RegisterRequest request) =>
      AuthRepository().registerRequest(request);

  static Future<void> changePassword(ChangePasswordRequest request) =>
      AuthRepository().changePasswordRequest(request);

  static Future<void> logout({bool clearRemoteCart = true}) =>
      AuthRepository().logoutRequest(clearRemoteCart: clearRemoteCart);
}
