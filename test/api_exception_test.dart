import 'package:flutter_test/flutter_test.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiException Tests', () {
    test('Parse lỗi nghiệp vụ (Business error)', () {
      final json = {
        'statusCode': 400,
        'errorCode': 'DOCTOR_HAS_ORDERS',
        'message': 'Bác sĩ đã có trong đơn hàng, không thể xóa',
      };

      final exception = ApiException.fromResponse(400, json);

      expect(exception.statusCode, 400);
      expect(exception.errorCode, 'DOCTOR_HAS_ORDERS');
      expect(exception.message, 'Bác sĩ đã có trong đơn hàng, không thể xóa');
      expect(exception.fieldErrors, isEmpty);
      expect(exception.displayMessage, 'Bác sĩ đã có trong đơn hàng, không thể xóa');
      expect(exception.combinedMessage, 'Bác sĩ đã có trong đơn hàng, không thể xóa');
      expect(exception.toString(), 'Bác sĩ đã có trong đơn hàng, không thể xóa');
    });

    test('Parse lỗi ValidationProblemDetails (errors theo field) và getter gộp hiển thị', () {
      final json = {
        'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'FullName': ['Vui lòng nhập họ và tên bác sĩ'],
          'Phone': [
            'Số điện thoại phải gồm 10 chữ số',
            'Số điện thoại phải bắt đầu bằng số 0',
          ],
        },
      };

      final exception = ApiException.fromResponse(400, json);

      expect(exception.statusCode, 400);
      expect(exception.errorCode, isNull);
      expect(exception.message, 'One or more validation errors occurred.');
      expect(exception.fieldErrors.length, 2);
      expect(exception.fieldErrors['FullName'], ['Vui lòng nhập họ và tên bác sĩ']);
      expect(exception.fieldErrors['Phone']!.length, 2);

      final combined = exception.displayMessage;
      expect(combined, contains('Vui lòng nhập họ và tên bác sĩ'));
      expect(combined, contains('Số điện thoại phải gồm 10 chữ số'));
      expect(combined, contains('Số điện thoại phải bắt đầu bằng số 0'));
      expect(exception.combinedMessage, combined);
      expect(exception.toString(), combined);
    });

    test('Xử lý 401 khi không có message tùy chỉnh trả về tiếng Việt', () {
      final exception = ApiException.fromResponse(401, null);
      expect(exception.statusCode, 401);
      expect(
        exception.displayMessage,
        contains('Phiên đăng nhập đã hết hạn'),
      );
    });

    test('Xử lý 403 và 404 mặc định', () {
      final exp403 = ApiException.fromResponse(403, null);
      expect(exp403.statusCode, 403);
      expect(exp403.displayMessage, contains('không có quyền'));

      final exp404 = ApiException.fromResponse(404, null);
      expect(exp404.statusCode, 404);
      expect(exp404.displayMessage, contains('Không tìm thấy dữ liệu'));
    });

    test('Lỗi mạng và Timeout tạo thông báo tiếng Việt', () {
      final netErr = ApiException.network();
      expect(netErr.statusCode, 0);
      expect(netErr.displayMessage, contains('Không kết nối được máy chủ'));

      final timeoutErr = ApiException.timeout();
      expect(timeoutErr.statusCode, 408);
      expect(timeoutErr.displayMessage, contains('Kết nối quá thời gian'));
    });
  });
}
