import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../config/app_config.dart';
import '../../helpers/session_helper.dart';
import 'api_exception.dart';

/// Đại diện cho 1 file tải lên dạng bytes
class MultipartFileItem {
  final String field;
  final List<int> bytes;
  final String filename;
  final MediaType? contentType;

  const MultipartFileItem({
    required this.field,
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  static MediaType? inferContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return null;
  }
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
    this.defaultTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? AppConfig.baseUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       ),
       _tokenProvider = tokenProvider ?? SessionHepler.getToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final Duration defaultTimeout;

  String get baseUrl => _baseUrl;

  /// Chuẩn hóa đường dẫn ảnh: trả null nếu path rỗng, giữ nguyên nếu đã là URL tuyệt đối,
  /// ghép an toàn với baseUrl nếu là đường dẫn tương đối.
  String? imageUrl(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$_baseUrl/$cleanPath';
  }

  Uri _resolveUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$_baseUrl/$cleanPath');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final query = <String, dynamic>{
        ...uri.queryParameters,
        ...queryParameters.map((k, v) => MapEntry(k, v?.toString())),
      }..removeWhere((k, v) => v == null);
      return uri.replace(queryParameters: query);
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool isJson = true,
  }) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decodedBody;
    final is2xx = response.statusCode >= 200 && response.statusCode < 300;

    if (response.bodyBytes.isNotEmpty) {
      final raw = utf8.decode(response.bodyBytes).trim();
      if (raw.isNotEmpty) {
        try {
          decodedBody = jsonDecode(raw);
        } catch (_) {
          if (is2xx) {
            throw ApiException(
              statusCode: response.statusCode,
              message: 'Dữ liệu phản hồi không hợp lệ',
            );
          }
          decodedBody = raw;
        }
      }
    }

    if (is2xx) {
      // 204 No Content hoặc body rỗng trả về null
      if (response.statusCode == 204 || decodedBody == null) {
        return null;
      }
      return decodedBody;
    }

    // Ném ApiException khi statusCode < 200 hoặc >= 300 (bao gồm cả 401)
    throw ApiException.fromResponse(response.statusCode, decodedBody);
  }

  Future<dynamic> _send(http.BaseRequest request, {Duration? timeout}) async {
    try {
      final streamedResponse = await _client
          .send(request)
          .timeout(timeout ?? defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException.timeout();
    } on http.ClientException catch (e) {
      throw ApiException.network(e.message);
    } on SocketException catch (e) {
      throw ApiException.network(e.message);
    } on HandshakeException catch (e) {
      throw ApiException.network(e.message);
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final req = http.Request('GET', uri);
    req.headers.addAll(
      await _buildHeaders(extraHeaders: headers, isJson: true),
    );
    return _send(req, timeout: timeout);
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final req = http.Request('POST', uri);
    req.headers.addAll(
      await _buildHeaders(extraHeaders: headers, isJson: true),
    );
    if (body != null) {
      req.body = body is String ? body : jsonEncode(body);
    }
    return _send(req, timeout: timeout);
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final req = http.Request('PUT', uri);
    req.headers.addAll(
      await _buildHeaders(extraHeaders: headers, isJson: true),
    );
    if (body != null) {
      req.body = body is String ? body : jsonEncode(body);
    }
    return _send(req, timeout: timeout);
  }

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final req = http.Request('DELETE', uri);
    req.headers.addAll(
      await _buildHeaders(extraHeaders: headers, isJson: true),
    );
    if (body != null) {
      req.body = body is String ? body : jsonEncode(body);
    }
    return _send(req, timeout: timeout);
  }

  /// Gửi multipart request với các trường và file dạng bytes (chạy được cả mobile và web)
  Future<dynamic> sendMultipart({
    required String method,
    required String path,
    Map<String, String>? fields,
    List<MultipartFileItem>? files,
    List<http.MultipartFile>? customFiles,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _resolveUri(path, queryParameters);
    final req = http.MultipartRequest(method, uri);
    req.headers.addAll(
      await _buildHeaders(extraHeaders: headers, isJson: false),
    );

    if (fields != null) {
      req.fields.addAll(fields);
    }

    if (files != null) {
      for (final f in files) {
        req.files.add(
          http.MultipartFile.fromBytes(
            f.field,
            f.bytes,
            filename: f.filename,
            contentType:
                f.contentType ?? MultipartFileItem.inferContentType(f.filename),
          ),
        );
      }
    }

    if (customFiles != null) {
      req.files.addAll(customFiles);
    }

    return _send(req, timeout: timeout);
  }

  /// Hỗ trợ gửi trực tiếp một `http.MultipartRequest` đã được cấu hình trước
  Future<dynamic> sendMultipartRequest(
    http.MultipartRequest request, {
    Duration? timeout,
  }) async {
    final token = await _tokenProvider();
    if (token != null &&
        token.isNotEmpty &&
        !request.headers.containsKey('Authorization')) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _send(request, timeout: timeout);
  }
}
