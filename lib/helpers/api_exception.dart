class ApiException implements Exception {
  const ApiException(this.message, {this.errorCode, this.statusCode});

  final String message;
  final String? errorCode;
  final int? statusCode;

  @override
  String toString() => message;
}

String parseApiErrorMessage(
  dynamic data,
  int statusCode, {
  String fallback = 'Không thực hiện được yêu cầu. Vui lòng thử lại.',
}) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          for (final item in value) {
            final text = item?.toString().trim() ?? '';
            if (text.isNotEmpty) {
              messages.add(text);
            }
          }
        } else if (value != null) {
          final text = value.toString().trim();
          if (text.isNotEmpty) {
            messages.add(text);
          }
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }

    final title = data['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
  }

  if (statusCode == 401) {
    return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
  }
  if (statusCode == 403) {
    return 'Bạn không có quyền thực hiện chức năng này.';
  }
  return fallback;
}
