import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../helpers/session_helper.dart';
import '../models/auth_models.dart';
import '../models/user_role_models.dart';

class AuthRepository {
  AuthRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
    ApiClient? apiClient,
  }) : baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _token = token ?? SessionHepler.getToken,
       _api =
           apiClient ??
           ApiClient(
             client: client,
             baseUrl: baseUrl,
             tokenProvider: token,
             defaultTimeout: const Duration(seconds: 20),
           ),
       _publicApi = ApiClient(
         client: client,
         baseUrl: baseUrl,
         tokenProvider: () async => null,
         defaultTimeout: const Duration(seconds: 20),
       );

  final String baseUrl;
  final Future<String?> Function() _token;
  final ApiClient _api;
  final ApiClient _publicApi;

  Future<SessionUser?> loginRequest(LoginRequest request) async {
    final data = await _publicApi.post(
      '/api/auth/login',
      body: request.toJson(),
    );
    if (data is Map && data['token'] is String) {
      final jwt = data['token'] as String;
      await SessionHepler.saveToken(jwt);
      return SessionHepler.decodeToken(jwt);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Đăng nhập không thành công',
    );
  }

  Future<RegisterResult> registerRequest(RegisterRequest request) async {
    final data = await _publicApi.post(
      '/api/auth/register',
      body: request.toJson(),
    );
    if (data is Map) {
      final msg =
          (data['message'] ?? data['Message'])?.toString() ??
          'Đăng ký tài khoản thành công.';
      final requiresVerify = data['requiresEmailVerification'] == true;
      final email = data['email'] is String ? data['email'] as String : null;
      final devOtp = data['devOtp'] is String ? data['devOtp'] as String : null;
      return RegisterResult(
        message: msg,
        requiresEmailVerification: requiresVerify,
        email: email,
        devOtp: devOtp,
      );
    }
    return const RegisterResult(message: 'Đăng ký tài khoản thành công.');
  }

  Future<void> changePasswordRequest(ChangePasswordRequest request) async {
    await _ensureToken();
    await _api.put('/api/auth/change-password', body: request.toJson());
  }

  Future<void> logoutRequest({bool clearRemoteCart = false}) async {
    try {
      final jwt = await _token();
      if (jwt != null && jwt.isNotEmpty) {
        await _api.post(
          '/api/auth/logout',
          timeout: const Duration(seconds: 5),
        );
      }
    } catch (_) {
      // Logout cục bộ vẫn phải tiếp tục dù server không phản hồi.
    } finally {
      await SessionHepler.clear(clearRemoteCart: clearRemoteCart);
    }
  }

  Future<ForgotPasswordResult> forgotPasswordRequest(
    ForgotPasswordRequest request,
  ) async {
    final data = await _publicApi.post(
      '/api/auth/forgot-password',
      body: request.toJson(),
    );
    final msg = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Mã OTP đặt lại mật khẩu đã được gửi tới email của bạn.';
    final devOtp = data is Map && data['devOtp'] is String
        ? data['devOtp'] as String
        : null;
    return ForgotPasswordResult(message: msg, devOtp: devOtp);
  }

  Future<void> resetPasswordRequest(ResetPasswordRequest request) async {
    await _publicApi.post('/api/auth/reset-password', body: request.toJson());
  }

  Future<void> verifyEmailRequest(VerifyEmailRequest request) async {
    await _publicApi.post('/api/auth/verify-email', body: request.toJson());
  }

  Future<ForgotPasswordResult> resendVerificationOtpRequest(
    String email,
  ) async {
    final data = await _publicApi.post(
      '/api/auth/resend-verify-email',
      body: {'email': email.trim()},
    );
    final msg = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Đã gửi lại mã OTP xác thực tới email của bạn.';
    final devOtp = data is Map && data['devOtp'] is String
        ? data['devOtp'] as String
        : null;
    return ForgotPasswordResult(message: msg, devOtp: devOtp);
  }

  Future<void> verifyPasswordRequest(String password) async {
    await _ensureToken();
    await _api.post('/api/auth/verify-password', body: {'password': password});
  }

  Future<MyProfile> getMyProfileRequest() async {
    await _ensureToken();
    final data = await _api.get('/api/auth/me');
    if (data is Map) {
      return MyProfile.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Không tải được thông tin cá nhân.',
    );
  }

  Future<MyProfile> updateMyProfileRequest(
    UpdateMyProfileRequest request,
  ) async {
    await _ensureToken();
    final data = await _api.put('/api/auth/me', body: request.toJson());
    if (data is Map) {
      if (data['token'] is String && (data['token'] as String).isNotEmpty) {
        await SessionHepler.saveToken(data['token'] as String);
      }
      final profileMap = data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : Map<String, dynamic>.from(data);
      return MyProfile.fromJson(profileMap);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Cập nhật thông tin không thành công.',
    );
  }

  Future<SocialLoginResult> socialLoginRequest(
    SocialLoginRequest request,
  ) async {
    final data = await _publicApi.post(
      '/api/auth/social-login',
      body: request.toJson(),
    );
    if (data is Map && data['token'] is String) {
      final jwt = data['token'] as String;
      await SessionHepler.saveToken(jwt);
      return SocialLoginResult(
        message: (data['message'] ?? 'Đăng nhập thành công!').toString(),
        provider: (data['provider'] ?? request.provider).toString(),
        isNewUser: data['isNewUser'] == true,
      );
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Đăng nhập mạng xã hội không thành công.',
    );
  }

  Future<void> _ensureToken() async {
    final jwt = await _token();
    if (jwt == null || jwt.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }

  static Future<SessionUser?> login(LoginRequest request) =>
      AuthRepository().loginRequest(request);

  static Future<RegisterResult> register(RegisterRequest request) =>
      AuthRepository().registerRequest(request);

  static Future<void> changePassword(ChangePasswordRequest request) =>
      AuthRepository().changePasswordRequest(request);

  static Future<void> logout({bool clearRemoteCart = false}) =>
      AuthRepository().logoutRequest(clearRemoteCart: clearRemoteCart);
}
