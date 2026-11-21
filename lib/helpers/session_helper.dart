import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/cart_repository.dart';

class SessionHepler {
  static const String _tokenKey = 'jwt_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clear() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      await CartRepository().clear();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isEmpty;
  }
}
