import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../helpers/api_exception.dart';
import '../models/auth_models.dart';

abstract class SocialAuthGateway {
  Future<SocialLoginRequest?> authenticate(String provider);
}

class NativeSocialAuthGateway implements SocialAuthGateway {
  const NativeSocialAuthGateway();

  static const String _googleWebClientId =
      '313931329689-h946g6j5pk38rlmjb3nmt4mugp7sobaa.apps.googleusercontent.com';

  static const MethodChannel _zaloChannel = MethodChannel(
    'com.medicalapp/zalo_auth',
  );

  @override
  Future<SocialLoginRequest?> authenticate(String provider) {
    return switch (provider.trim().toLowerCase()) {
      'google' || 'gmail' => _signInWithGoogle(),
      'facebook' => _signInWithFacebook(),
      'zalo' => _signInWithZalo(),
      _ => throw const ApiException('Phương thức đăng nhập không hợp lệ.'),
    };
  }

  Future<SocialLoginRequest?> _signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: _googleWebClientId,
    );

    try {
      await googleSignIn.signOut();
    } catch (_) {}

    try {
      final account = await googleSignIn.signIn();
      if (account == null) {
        return null;
      }

      final auth = await account.authentication;
      if ((auth.idToken == null || auth.idToken!.isEmpty) &&
          (auth.accessToken == null || auth.accessToken!.isEmpty)) {
        throw const ApiException(
          'Không lấy được mã xác thực từ Google. Vui lòng thử lại.',
        );
      }

      return SocialLoginRequest(
        provider: 'Google',
        idToken: auth.idToken,
        accessToken: auth.accessToken,
        email: account.email,
        fullName: account.displayName,
        avatarUrl: account.photoUrl,
      );
    } on ApiException {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == GoogleSignIn.kSignInCanceledError) {
        return null;
      }
      throw ApiException(
        'Đăng nhập Google thất bại (${e.code}). Kiểm tra kết nối mạng và cấu hình SHA-1.',
      );
    } catch (_) {
      throw const ApiException('Không thể khởi tạo đăng nhập Google.');
    }
  }

  Future<SocialLoginRequest?> _signInWithFacebook() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}

    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        return null;
      }

      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw ApiException(
          result.message ?? 'Đăng nhập Facebook không thành công.',
        );
      }

      return SocialLoginRequest(
        provider: 'Facebook',
        accessToken: result.accessToken!.tokenString,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Không thể mở đăng nhập Facebook: $e');
    }
  }

  Future<SocialLoginRequest?> _signInWithZalo() async {
    final codeVerifier = _generatePkceVerifier();
    final codeChallenge = _computePkceChallenge(codeVerifier);

    try {
      final res = await _zaloChannel.invokeMapMethod<String, dynamic>(
        'login',
        {'codeChallenge': codeChallenge},
      );
      final oauthCode = res?['oauthCode']?.toString().trim() ?? '';
      if (oauthCode.isEmpty) {
        return null;
      }

      return SocialLoginRequest(
        provider: 'Zalo',
        oauthCode: oauthCode,
        codeVerifier: codeVerifier,
      );
    } on MissingPluginException {
      throw const ApiException(
        'Đăng nhập Zalo chỉ hỗ trợ trên ứng dụng Android đã cài đặt.',
      );
    } on PlatformException catch (e) {
      if (e.details == -1114 ||
          (e.message?.toLowerCase().contains('cancel') ?? false)) {
        return null;
      }
      throw ApiException(
        e.message ?? 'Đăng nhập Zalo không thành công (${e.details}).',
      );
    }
  }

  static String _generatePkceVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return List.generate(43, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String _computePkceChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
