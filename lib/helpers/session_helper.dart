import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role_models.dart';
import '../repositories/cart_repository.dart';
import 'local_database_helper.dart';

typedef SessionHelper = SessionHepler;

class SessionHepler {
  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';

  static const String _claimNameId =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';
  static const String _claimPhone =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone';
  static const String _claimName =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
  static const String _claimRole =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  /// Giải mã claim Role từ JWT payload (Base64 thuần, không cần package bên ngoài)
  static String? decodeRoleFromToken(String token) {
    try {
      final parts = token.trim().split('.');
      if (parts.length < 2) {
        return null;
      }
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedJson = utf8.decode(base64Decode(payload));
      final map = jsonDecode(decodedJson);
      if (map is Map<String, dynamic>) {
        final role = map['Role'] ?? map['role'] ?? map[_claimRole];
        if (role != null) {
          return role.toString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static SessionUser? decodeToken(String token) {
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3) {
        return null;
      }
      final payloadJson = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payloadJson);
      if (claims is! Map<String, dynamic>) {
        return null;
      }

      final rawId = claims[_claimNameId] ?? claims['nameid'] ?? claims['sub'];
      final userId = int.tryParse(rawId?.toString() ?? '') ?? 0;
      final fullName =
          (claims[_claimName] ?? claims['unique_name'] ?? claims['name'] ?? '')
              .toString();
      final phone = (claims[_claimPhone] ?? claims['phone'] ?? '').toString();
      final roleKey =
          (claims[_claimRole] ?? claims['Role'] ?? claims['role'] ?? 'PATIENT')
              .toString()
              .trim();

      DateTime? expiresAt;
      final exp = claims['exp'];
      if (exp is num) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        ).toLocal();
      }

      return SessionUser(
        userId: userId,
        fullName: fullName,
        phone: phone,
        roleKey: roleKey.isEmpty ? 'PATIENT' : roleKey,
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    final role = decodeRoleFromToken(token);
    if (role != null) {
      await prefs.setString(_roleKey, role);
    } else {
      await prefs.remove(_roleKey);
    }

    final user = decodeToken(token);
    if (user != null) {
      try {
        await LocalDatabaseHelper.saveSession(user, token);
      } catch (_) {}
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsToken = prefs.getString(_tokenKey);
    if (prefsToken != null && prefsToken.isNotEmpty) {
      return prefsToken;
    }

    try {
      final stored = await LocalDatabaseHelper.getSession();
      if (stored != null && stored.token.isNotEmpty) {
        await prefs.setString(_tokenKey, stored.token);
        await prefs.setString(_roleKey, stored.user.roleKey);
        return stored.token;
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    if (role != null && role.isNotEmpty) {
      return role;
    }
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      return decodeRoleFromToken(token);
    }
    return null;
  }

  static Future<SessionUser?> getCurrentUser() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final user = decodeToken(token);
    if (user == null || user.isExpired) {
      await clear(clearRemoteCart: false);
      return null;
    }
    return user;
  }

  static Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    if (user != null) {
      return user.isAdmin;
    }
    final role = await getRole();
    return role?.toUpperCase() == 'ADMIN';
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    final user = decodeToken(token);
    if (user != null && user.isExpired) {
      await clear(clearRemoteCart: false);
      return false;
    }
    return true;
  }

  static Future<void> clear({
    bool clearRemoteCart = true,
    CartRepository? cartRepository,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (clearRemoteCart && token != null && token.isNotEmpty) {
        try {
          final cart = cartRepository ?? CartRepository();
          await cart.clear();
        } catch (_) {
          // Best-effort dọn giỏ trên server, không chặn đăng xuất nếu mạng/server lỗi
        }
      }
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_roleKey);
      try {
        await LocalDatabaseHelper.clearSession();
        await LocalDatabaseHelper.clearAllCaches();
      } catch (_) {}
    }
  }
}
