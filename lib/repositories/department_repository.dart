import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/department.dart';

class DepartmentRepository {
  DepartmentRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
    ApiClient? apiClient,
  }) : baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
       _api =
           apiClient ??
           ApiClient(
             client: client,
             baseUrl: baseUrl,
             tokenProvider: token,
           );

  final String baseUrl;
  final ApiClient _api;

  String? imageUrl(String? path) => _api.imageUrl(path);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (e.errorCode == 'DEPARTMENT_HAS_DOCTORS') {
        throw ApiException(
          statusCode: e.statusCode,
          errorCode: e.errorCode,
          message: 'Khoa còn bác sĩ, không thể xóa',
          fieldErrors: e.fieldErrors,
        );
      }
      rethrow;
    }
  }

  Future<List<Department>> list() async => _guard(() async {
    final data = await _api.get('/api/departments');
    return ((data as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Department.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  });

  Future<Department> save({
    int? id,
    required String name,
    required String description,
    double? consultationFee,
    String? imageUrl,
  }) async => _guard(() async {
    final body = {
      'name': name,
      'description': description,
      'consultationFee': ?consultationFee,
      'imageUrl': imageUrl,
    };
    final data = id == null
        ? await _api.post('/api/departments', body: body)
        : await _api.put('/api/departments/$id', body: body);
    return Department.fromJson(Map<String, dynamic>.from(data as Map));
  });

  Future<Department> deleteImage(int id) async => _guard(() async {
    final data = await _api.delete('/api/departments/$id/image');
    return Department.fromJson(Map<String, dynamic>.from(data as Map));
  });

  Future<Department> upload(int id, List<int> bytes, String name) async =>
      _guard(() async {
        final ext = name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final data = await _api.sendMultipart(
          method: 'POST',
          path: '/api/departments/$id/image',
          files: [
            MultipartFileItem(
              field: 'file',
              bytes: bytes,
              filename: name,
              contentType: MediaType('image', ext),
            ),
          ],
        );
        return Department.fromJson(Map<String, dynamic>.from(data as Map));
      });

  Future<Department> setImageUrl(int id, String imageUrl) async =>
      _guard(() async {
        final data = await _api.post(
          '/api/departments/$id/image/url',
          body: {'imageUrl': imageUrl},
        );
        return Department.fromJson(Map<String, dynamic>.from(data as Map));
      });

  Future<void> delete(int id) async => _guard(() async {
    await _api.delete('/api/departments/$id');
  });
}
