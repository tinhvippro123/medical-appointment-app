import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../helpers/api_exception.dart';
import '../helpers/local_database_helper.dart';
import '../helpers/session_helper.dart';
import '../models/user_role_models.dart';

class UserRepository {
  UserRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
    this.enableCache = true,
  }) : _client = client ?? http.Client(),
       baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _token = token ?? SessionHepler.getToken;

  final http.Client _client;
  final String baseUrl;
  final Future<String?> Function() _token;
  final bool enableCache;

  Future<dynamic> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final jwt = await _token();
    final request = http.Request(method, uri);
    if (jwt != null && jwt.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $jwt';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 20));

      dynamic data;
      if (response.bodyBytes.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          parseApiErrorMessage(data, response.statusCode),
          errorCode: data is Map ? data['errorCode'] as String? : null,
          statusCode: response.statusCode,
        );
      }

      return data;
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

  Future<PagedUsers> list({
    int page = 1,
    int pageSize = 10,
    String? keyword,
    int? roleId,
    bool? isActive,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final trimmedKeyword = keyword?.trim();
    if (trimmedKeyword != null && trimmedKeyword.isNotEmpty) {
      params['keyword'] = trimmedKeyword;
    }
    if (roleId != null) {
      params['roleId'] = '$roleId';
    }
    if (isActive != null) {
      params['isActive'] = isActive.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/api/users',
    ).replace(queryParameters: params);

    try {
      final data = await _send('GET', uri);
      final result = PagedUsers.fromJson(data as Map<String, dynamic>);

      final isUnfilteredFirstPage =
          page == 1 &&
          (trimmedKeyword == null || trimmedKeyword.isEmpty) &&
          roleId == null &&
          isActive == null;
      if (isUnfilteredFirstPage && enableCache) {
        try {
          await LocalDatabaseHelper.cacheUsers(result.items);
        } catch (_) {}
      }
      return result;
    } on ApiException catch (e) {
      if (e.statusCode == null && enableCache) {
        final cached = await LocalDatabaseHelper.getCachedUsers();
        if (cached.isNotEmpty) {
          final filtered = cached.where((user) {
            if (trimmedKeyword != null && trimmedKeyword.isNotEmpty) {
              final q = trimmedKeyword.toLowerCase();
              final matches =
                  user.fullName.toLowerCase().contains(q) ||
                  user.phone.toLowerCase().contains(q) ||
                  (user.email?.toLowerCase().contains(q) ?? false);
              if (!matches) {
                return false;
              }
            }
            if (roleId != null && user.roleId != roleId) {
              return false;
            }
            if (isActive != null && user.isActive != isActive) {
              return false;
            }
            return true;
          }).toList();

          return PagedUsers(
            items: filtered,
            totalCount: filtered.length,
            page: 1,
            pageSize: filtered.isEmpty ? pageSize : filtered.length,
            totalPages: 1,
            hasPreviousPage: false,
            hasNextPage: false,
            isFromCache: true,
          );
        }
      }
      rethrow;
    }
  }

  Future<UserItem> create({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    required int roleId,
  }) async {
    final trimmedEmail = email?.trim();
    final data = await _send(
      'POST',
      Uri.parse('$baseUrl/api/users'),
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': trimmedEmail == null || trimmedEmail.isEmpty
            ? null
            : trimmedEmail,
        'password': password,
        'roleId': roleId,
      },
    );
    return UserItem.fromJson(data as Map<String, dynamic>);
  }

  Future<UserItem> update(
    int id, {
    required String fullName,
    required String phone,
    String? email,
    required int roleId,
    required bool isActive,
  }) async {
    final trimmedEmail = email?.trim();
    final data = await _send(
      'PUT',
      Uri.parse('$baseUrl/api/users/$id'),
      body: {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'email': trimmedEmail == null || trimmedEmail.isEmpty
            ? null
            : trimmedEmail,
        'roleId': roleId,
        'isActive': isActive,
      },
    );
    return UserItem.fromJson(data as Map<String, dynamic>);
  }

  Future<UserItem> updateRole(int id, int roleId) async {
    final data = await _send(
      'PUT',
      Uri.parse('$baseUrl/api/users/$id/role'),
      body: {'roleId': roleId},
    );
    return UserItem.fromJson(data as Map<String, dynamic>);
  }

  Future<UserItem> updateStatus(int id, bool isActive) async {
    final data = await _send(
      'PATCH',
      Uri.parse('$baseUrl/api/users/$id/status'),
      body: {'isActive': isActive},
    );
    return UserItem.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _send('DELETE', Uri.parse('$baseUrl/api/users/$id'));
  }
}
