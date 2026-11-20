import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import '../helpers/session_helper.dart';
import '../models/department.dart';

class DepartmentApiException implements Exception {
  const DepartmentApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DepartmentRepository {
  DepartmentRepository({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
  }) : _client = client ?? http.Client(),
       baseUrl = baseUrl ?? AppConfig.baseUrl,
       _token = token ?? SessionHepler.getToken;
  final http.Client _client;
  final String baseUrl;
  final Future<String?> Function() _token;
  String? imageUrl(String? path) => path == null || path.isEmpty
      ? null
      : Uri.parse('$baseUrl/').resolve(path).toString();
  Future<dynamic> _send(http.BaseRequest request) async {
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 30));
      dynamic data;
      try {
        if (response.bodyBytes.isNotEmpty) {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        }
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (data is Map && data['errorCode'] == 'DEPARTMENT_HAS_DOCTORS') {
          throw const DepartmentApiException('Khoa còn bác sĩ, không thể xóa');
        }
        throw DepartmentApiException(
          data is Map && data['message'] is String
              ? data['message'] as String
              : 'Không thực hiện được yêu cầu (${response.statusCode}). Vui lòng thử lại.',
        );
      }
      return data;
    } on DepartmentApiException {
      rethrow;
    } on TimeoutException {
      throw const DepartmentApiException(
        'Kết nối quá thời gian. Vui lòng thử lại.',
      );
    } catch (_) {
      throw const DepartmentApiException(
        'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
  }

  Future<List<Department>> list() async =>
      ((await _send(http.Request('GET', Uri.parse('$baseUrl/api/departments'))))
              as List)
          .map((e) => Department.fromJson(e as Map<String, dynamic>))
          .toList();
  Future<Department> save({
    int? id,
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    final request = http.Request(
      id == null ? 'POST' : 'PUT',
      Uri.parse('$baseUrl/api/departments${id == null ? '' : '/$id'}'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
    });
    return Department.fromJson(await _send(request) as Map<String, dynamic>);
  }

  Future<Department> upload(int id, List<int> bytes, String name) async {
    final ext = name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/departments/$id/image'),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: name,
              contentType: MediaType('image', ext),
            ),
          );
    return Department.fromJson(await _send(request) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _send(
      http.Request('DELETE', Uri.parse('$baseUrl/api/departments/$id')),
    );
  }
}
