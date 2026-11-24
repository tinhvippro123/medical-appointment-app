import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/cart_repository.dart';

class SessionHepler {
  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';

  /// Giải mã claim Role từ JWT payload (Base64 thuần, không cần package bên ngoài)
  static String? decodeRoleFromToken(String token) {
    try {
      final parts = token.trim().split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedJson = utf8.decode(base64Decode(payload));
      final map = jsonDecode(decodedJson);
      if (map is Map<String, dynamic>) {
        final role = map['Role'] ??
            map['role'] ??
            map['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'];
        if (role != null) {
          return role.toString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
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
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == 'ADMIN';
  }

  static Future<void> clear({CartRepository? cartRepository}) async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
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
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
