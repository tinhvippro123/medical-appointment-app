import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role_models.dart';
import '../repositories/cart_repository.dart';
import 'local_database_helper.dart';

typedef SessionHelper = SessionHepler;

class SessionHepler {
  static const String _tokenKey = 'jwt_token';

  static const String _claimNameId =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';
  static const String _claimPhone =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone';
  static const String _claimName =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
  static const String _claimRole =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  static SessionUser? decodeToken(String token) {
    try {
      final parts = token.split('.');
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
      final roleKey = (claims[_claimRole] ?? claims['role'] ?? 'PATIENT')
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
        return stored.token;
      }
    } catch (_) {}

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
    return user?.isAdmin ?? false;
  }

  static Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  static Future<void> clear({bool clearRemoteCart = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (clearRemoteCart && token != null && token.isNotEmpty) {
      try {
        await CartRepository().clear();
      } catch (_) {}
    }
    await prefs.remove(_tokenKey);
    try {
      await LocalDatabaseHelper.clearSession();
      await LocalDatabaseHelper.clearAllCaches();
    } catch (_) {}
  }
}
