import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../helpers/api_exception.dart';
import '../helpers/local_database_helper.dart';
import '../helpers/session_helper.dart';
import '../models/user_role_models.dart';

class RoleRepository {
  RoleRepository({
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
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final jwt = await _token();
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
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

  Future<RoleListResult> list() async {
    try {
      final data = await _send('GET', '/api/roles');
      final items = ((data as List?) ?? const [])
          .map((e) => RoleItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (enableCache) {
        try {
          await LocalDatabaseHelper.cacheRoles(items);
        } catch (_) {}
      }
      return RoleListResult(items: items);
    } on ApiException catch (e) {
      if (e.statusCode == null && enableCache) {
        final cached = await LocalDatabaseHelper.getCachedRoles();
        if (cached.isNotEmpty) {
          return RoleListResult(items: cached, isFromCache: true);
        }
      }
      rethrow;
    }
  }

  Future<RoleItem> create({
    required String key,
    required String name,
    String? description,
  }) async {
    final trimmedDesc = description?.trim();
    final data = await _send(
      'POST',
      '/api/roles',
      body: {
        'key': key.trim().toUpperCase(),
        'name': name.trim(),
        'description': trimmedDesc == null || trimmedDesc.isEmpty
            ? null
            : trimmedDesc,
      },
    );
    return RoleItem.fromJson(data as Map<String, dynamic>);
  }

  Future<RoleItem> update(
    int id, {
    required String key,
    required String name,
    String? description,
  }) async {
    final trimmedDesc = description?.trim();
    final data = await _send(
      'PUT',
      '/api/roles/$id',
      body: {
        'key': key.trim().toUpperCase(),
        'name': name.trim(),
        'description': trimmedDesc == null || trimmedDesc.isEmpty
            ? null
            : trimmedDesc,
      },
    );
    return RoleItem.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _send('DELETE', '/api/roles/$id');
  }
}
