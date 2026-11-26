import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../helpers/local_database_helper.dart';
import '../models/user_role_models.dart';

class UserRepository {
  UserRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
    ApiClient? apiClient,
    this.enableCache = true,
  }) : baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _api =
           apiClient ??
           ApiClient(
             client: client,
             baseUrl: baseUrl,
             tokenProvider: token,
             defaultTimeout: const Duration(seconds: 20),
           );

  final String baseUrl;
  final ApiClient _api;
  final bool enableCache;

  Future<PagedUsers> list({
    int page = 1,
    int pageSize = 10,
    String? keyword,
    int? roleId,
    bool? isActive,
  }) async {
    final params = <String, dynamic>{'page': page, 'pageSize': pageSize};
    final trimmedKeyword = keyword?.trim();
    if (trimmedKeyword != null && trimmedKeyword.isNotEmpty) {
      params['keyword'] = trimmedKeyword;
    }
    if (roleId != null) {
      params['roleId'] = roleId;
    }
    if (isActive != null) {
      params['isActive'] = isActive.toString();
    }

    try {
      final data = await _api.get('/api/users', queryParameters: params);
      final result = PagedUsers.fromJson(
        Map<String, dynamic>.from(data as Map),
      );

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
      if ((e.statusCode == 0 || e.statusCode == 408) && enableCache) {
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
    final data = await _api.post(
      '/api/users',
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
    return UserItem.fromJson(Map<String, dynamic>.from(data as Map));
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
    final data = await _api.put(
      '/api/users/$id',
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
    return UserItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<UserItem> updateRole(int id, int roleId) async {
    final data = await _api.put(
      '/api/users/$id/role',
      body: {'roleId': roleId},
    );
    return UserItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<UserItem> updateStatus(int id, bool isActive) async {
    final data = await _api.patch(
      '/api/users/$id/status',
      body: {'isActive': isActive},
    );
    return UserItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/users/$id');
  }
}
