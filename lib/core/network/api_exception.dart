class ApiException implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;
  final Map<String, List<String>> fieldErrors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.fieldErrors = const {},
  });

  /// Factory parse từ HTTP status code và dynamic decoded response body
  factory ApiException.fromResponse(int statusCode, dynamic body) {
    String? errorCode;
    String message = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    final fieldErrors = <String, List<String>>{};

    if (body is Map<String, dynamic>) {
      // 1. Mã lỗi nghiệp vụ
      if (body['errorCode'] is String) {
        errorCode = body['errorCode'] as String;
      }

      // 2. Message nghiệp vụ
      if (body['message'] is String && (body['message'] as String).trim().isNotEmpty) {
        message = (body['message'] as String).trim();
      } else if (body['title'] is String && (body['title'] as String).trim().isNotEmpty) {
        message = (body['title'] as String).trim();
      }

      // 3. ValidationProblemDetails (errors: { "Field": ["Error 1", "Error 2"] })
      if (body['errors'] is Map) {
        final rawErrors = body['errors'] as Map;
        for (final entry in rawErrors.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is List) {
            fieldErrors[key] = val.map((e) => e.toString()).toList();
          } else if (val != null) {
            fieldErrors[key] = [val.toString()];
          }
        }
      }
    } else if (body is String && body.trim().isNotEmpty) {
      message = body.trim();
    }

    // Gán thông báo mặc định nếu chưa có
    if (message == 'Đã có lỗi xảy ra. Vui lòng thử lại.') {
      if (statusCode == 401) {
        message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      } else if (statusCode == 403) {
        message = 'Bạn không có quyền thực hiện thao tác này.';
      } else if (statusCode == 404) {
        message = 'Không tìm thấy dữ liệu yêu cầu.';
      }
    }

    return ApiException(
      statusCode: statusCode,
      errorCode: errorCode,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  /// Factory cho lỗi kết nối mạng
  factory ApiException.network([String? detail]) => ApiException(
    statusCode: 0,
    message: detail ?? 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
  );

  /// Factory cho lỗi quá thời gian chờ (Timeout)
  factory ApiException.timeout() => const ApiException(
    statusCode: 408,
    message: 'Kết nối quá thời gian. Vui lòng thử lại.',
  );

  /// Getter trả về thông báo lỗi tiếng Việt gộp các lỗi trường
  String get displayMessage {
    if (fieldErrors.isNotEmpty) {
      final allErrors = fieldErrors.values
          .expand((list) => list)
          .where((e) => e.trim().isNotEmpty);
      if (allErrors.isNotEmpty) {
        return allErrors.join('\n');
      }
    }
    return message;
  }

  /// Alias cho displayMessage
  String get combinedMessage => displayMessage;

  @override
  String toString() => displayMessage;
}
