import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../helpers/local_database_helper.dart';
import '../models/user_role_models.dart';

class RoleRepository {
  RoleRepository({
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

  Future<RoleListResult> list() async {
    try {
      final data = await _api.get('/api/roles');
      final items = ((data as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RoleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (enableCache) {
        try {
          await LocalDatabaseHelper.cacheRoles(items);
        } catch (_) {}
      }
      return RoleListResult(items: items);
    } on ApiException catch (e) {
      if ((e.statusCode == 0 || e.statusCode == 408) && enableCache) {
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
    final data = await _api.post(
      '/api/roles',
      body: {
        'key': key.trim().toUpperCase(),
        'name': name.trim(),
        'description': trimmedDesc == null || trimmedDesc.isEmpty
            ? null
            : trimmedDesc,
      },
    );
    return RoleItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<RoleItem> update(
    int id, {
    required String key,
    required String name,
    String? description,
  }) async {
    final trimmedDesc = description?.trim();
    final data = await _api.put(
      '/api/roles/$id',
      body: {
        'key': key.trim().toUpperCase(),
        'name': name.trim(),
        'description': trimmedDesc == null || trimmedDesc.isEmpty
            ? null
            : trimmedDesc,
      },
    );
    return RoleItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/roles/$id');
  }
}
