import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/models/paged_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient Tests', () {
    test('Gắn Authorization: Bearer token khi token có giá trị', () async {
      String? authHeader;
      final mockClient = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response.bytes(
          utf8.encode('{"ok": true}'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'sample_jwt_token',
      );

      final res = await client.get('/api/test');
      expect(authHeader, 'Bearer sample_jwt_token');
      expect(res, {'ok': true});
    });

    test('Không gắn Authorization header khi token null hoặc rỗng', () async {
      String? authHeader;
      final mockClient = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response.bytes(
          utf8.encode('{"ok": true}'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
      );

      await client.get('/api/test');
      expect(authHeader, isNull);
    });

    test('Xử lý 204 No Content và body rỗng trả về null không crash jsonDecode', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE') {
          return http.Response.bytes(const [], 204);
        }
        return http.Response.bytes(const [], 200);
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
      );

      final deleteResult = await client.delete('/api/items/1');
      expect(deleteResult, isNull);

      final emptyBodyResult = await client.put('/api/items/1', body: {});
      expect(emptyBodyResult, isNull);
    });

    test('Gặp 400 ném ApiException với đúng format lỗi và giải mã UTF-8 tiếng Việt', () async {
      final mockClient = MockClient((request) async {
        final body = jsonEncode({
          'statusCode': 400,
          'errorCode': 'DOCTOR_HAS_ORDERS',
          'message': 'Bác sĩ đã có trong đơn hàng',
        });
        return http.Response.bytes(
          utf8.encode(body),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
      );

      expect(
        () => client.delete('/api/doctors/1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.errorCode, 'errorCode', 'DOCTOR_HAS_ORDERS')
              .having((e) => e.message, 'message', 'Bác sĩ đã có trong đơn hàng'),
        ),
      );
    });

    test('Gặp 401 ném ApiException(401) mà không xóa session hay chuyển hướng', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Unauthorized'})),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'expired_token',
      );

      expect(
        () => client.get('/api/profile'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthorized'),
        ),
      );
    });

    test('Xử lý TimeoutException chuyển thành ApiException(408)', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 120));
        return http.Response.bytes(
          utf8.encode('{"ok": true}'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
        defaultTimeout: const Duration(milliseconds: 40),
      );

      expect(
        () => client.get('/api/timeout'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 408)
              .having((e) => e.displayMessage, 'displayMessage', contains('Kết nối quá thời gian')),
        ),
      );
    });

    test('Lỗi kết nối mạng (ClientException) chuyển thành ApiException(0)', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network down', request.url);
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
      );

      expect(
        () => client.get('/api/network-error'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.displayMessage, 'displayMessage', contains('Network down')),
        ),
      );
    });

    test('Phản hồi 200 nhưng body JSON không hợp lệ ném ApiException thông báo phù hợp', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('Not a valid JSON {{{'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
      );

      expect(
        () => client.get('/api/invalid-json'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having((e) => e.message, 'message', 'Dữ liệu phản hồi không hợp lệ'),
        ),
      );
    });

    test('Xử lý imageUrl an toàn và chuẩn xác', () {
      final client = ApiClient(baseUrl: 'http://localhost:5041');

      expect(client.imageUrl(null), isNull);
      expect(client.imageUrl(''), isNull);
      expect(client.imageUrl('   '), isNull);
      expect(
        client.imageUrl('https://cdn.example.com/photo.jpg'),
        'https://cdn.example.com/photo.jpg',
      );
      expect(
        client.imageUrl('/images/doctors/doc1.png'),
        'http://localhost:5041/images/doctors/doc1.png',
      );
      expect(
        client.imageUrl('images/doctors/doc1.png'),
        'http://localhost:5041/images/doctors/doc1.png',
      );
    });

    test('sendMultipart gửi trường và file dạng bytes với UTF-8 an toàn', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        final body = jsonEncode({'id': 1, 'fullName': 'Bác sĩ A'});
        return http.Response.bytes(
          utf8.encode(body),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final client = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'multipart_token',
      );

      final res = await client.sendMultipart(
        method: 'POST',
        path: '/api/doctors',
        fields: {'FullName': 'Bác sĩ A', 'DepartmentId': '2'},
        files: [
          MultipartFileItem(
            field: 'Image',
            bytes: utf8.encode('dummy-image-bytes'),
            filename: 'avatar.png',
          ),
        ],
      );

      expect(requests.last.method, 'POST');
      expect(requests.last.headers['Authorization'], 'Bearer multipart_token');
      expect(
        requests.last.headers['content-type'],
        contains('multipart/form-data'),
      );
      expect(requests.last.body, contains('name="FullName"'));
      expect(requests.last.body, contains('Bác sĩ A'));
      expect(requests.last.body, contains('name="DepartmentId"'));
      expect(requests.last.body, contains('2'));
      expect(requests.last.body, contains('filename="avatar.png"'));
      expect(requests.last.body, contains('dummy-image-bytes'));
      expect(res['id'], 1);
    });
  });

  group('PagedResult Tests', () {
    test('PagedResult.fromJson parse danh sách generic chính xác', () {
      final json = {
        'items': [
          {'id': 1, 'name': 'BS Nguyễn Văn A'},
          {'id': 2, 'name': 'BS Trần Thị B'},
        ],
        'totalCount': 25,
        'page': 1,
        'pageSize': 10,
        'totalPages': 3,
        'hasPreviousPage': false,
        'hasNextPage': true,
      };

      final paged = PagedResult<Map<String, dynamic>>.fromJson(
        json,
        (item) => item as Map<String, dynamic>,
      );

      expect(paged.items.length, 2);
      expect(paged.items[0]['name'], 'BS Nguyễn Văn A');
      expect(paged.totalCount, 25);
      expect(paged.page, 1);
      expect(paged.pageSize, 10);
      expect(paged.totalPages, 3);
      expect(paged.hasPreviousPage, isFalse);
      expect(paged.hasNextPage, isTrue);
    });

    test('PagedResult.empty khởi tạo danh sách rỗng đúng', () {
      final empty = PagedResult<String>.empty(page: 2, pageSize: 5);
      expect(empty.items, isEmpty);
      expect(empty.totalCount, 0);
      expect(empty.page, 2);
      expect(empty.pageSize, 5);
      expect(empty.totalPages, 0);
      expect(empty.hasPreviousPage, isFalse);
      expect(empty.hasNextPage, isFalse);
    });
  });
}
