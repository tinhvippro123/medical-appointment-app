import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/repositories/cart_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

String createFakeJwt(Map<String, dynamic> payload) {
  final headerBase64 = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payloadBase64 = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return '$headerBase64.$payloadBase64.fake_signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionHepler Role & JWT Tests', () {
    test('decodeRoleFromToken giải mã claim "Role": "ADMIN" chính xác', () {
      final token = createFakeJwt({'Role': 'ADMIN', 'sub': '1'});
      final role = SessionHepler.decodeRoleFromToken(token);

      expect(role, 'ADMIN');
    });

    test('decodeRoleFromToken giải mã claim URI chuẩn Microsoft .NET của backend', () {
      final token = createFakeJwt({
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'ADMIN',
        'sub': '1',
      });
      final role = SessionHepler.decodeRoleFromToken(token);

      expect(role, 'ADMIN');
    });

    test('decodeRoleFromToken giải mã claim "Role": "PATIENT" chính xác', () {
      final token = createFakeJwt({'Role': 'PATIENT', 'sub': '2'});
      final role = SessionHepler.decodeRoleFromToken(token);

      expect(role, 'PATIENT');
    });

    test('decodeRoleFromToken trả về null khi token hỏng hoặc không chứa claim role', () {
      // 1. Chuỗi không đúng cấu trúc JWT (không đủ dấu chấm)
      expect(SessionHepler.decodeRoleFromToken('invalid_token_string'), isNull);

      // 2. Chuỗi rỗng
      expect(SessionHepler.decodeRoleFromToken(''), isNull);

      // 3. Payload không phải base64 hợp lệ
      expect(SessionHepler.decodeRoleFromToken('header.invalid#base64.signature'), isNull);

      // 4. Payload hợp lệ nhưng không có claim role
      final tokenNoRole = createFakeJwt({'sub': '10', 'name': 'User'});
      expect(SessionHepler.decodeRoleFromToken(tokenNoRole), isNull);
    });

    test('saveToken lưu cả token và role; isAdmin() kiểm tra đúng vai trò', () async {
      final adminToken = createFakeJwt({'Role': 'ADMIN'});
      await SessionHepler.saveToken(adminToken);

      expect(await SessionHepler.getToken(), adminToken);
      expect(await SessionHepler.getRole(), 'ADMIN');
      expect(await SessionHepler.isAdmin(), isTrue);

      final patientToken = createFakeJwt({'Role': 'PATIENT'});
      await SessionHepler.saveToken(patientToken);

      expect(await SessionHepler.getRole(), 'PATIENT');
      expect(await SessionHepler.isAdmin(), isFalse);
    });

    test('clear() xóa sạch token và role ngay cả khi CartRepository gặp lỗi', () async {
      final adminToken = createFakeJwt({'Role': 'ADMIN'});
      await SessionHepler.saveToken(adminToken);

      expect(await SessionHepler.isLoggedIn(), isTrue);

      final failingClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('{"message": "Server error"}'),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final failingCartRepo = CartRepository(
        client: failingClient,
        baseUrl: 'http://test.api',
      );

      // Best-effort: lỗi dọn giỏ không ném Exception ra ngoài và vẫn xóa sạch token, role
      await SessionHepler.clear(
        clearRemoteCart: true,
        cartRepository: failingCartRepo,
      );

      expect(await SessionHepler.getToken(), isNull);
      expect(await SessionHepler.getRole(), isNull);
      expect(await SessionHepler.isLoggedIn(), isFalse);
      expect(await SessionHepler.isAdmin(), isFalse);
    });

    test('clear() hoạt động bình thường và xóa token/role khi bật clearRemoteCart', () async {
      final patientToken = createFakeJwt({'Role': 'PATIENT'});
      await SessionHepler.saveToken(patientToken);

      expect(await SessionHepler.isLoggedIn(), isTrue);

      var cartClearCalled = false;
      final successClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path == '/api/cart/clear') {
          cartClearCalled = true;
          return http.Response.bytes(const [], 204);
        }
        return http.Response.bytes(const [], 200);
      });
      final successCartRepo = CartRepository(
        client: successClient,
        baseUrl: 'http://test.api',
      );

      await SessionHepler.clear(
        clearRemoteCart: true,
        cartRepository: successCartRepo,
      );

      expect(cartClearCalled, isTrue);
      expect(await SessionHepler.getToken(), isNull);
      expect(await SessionHepler.getRole(), isNull);
      expect(await SessionHepler.isLoggedIn(), isFalse);
      expect(await SessionHepler.isAdmin(), isFalse);
    });

    test('clear() mặc định KHÔNG gọi DELETE /api/cart/clear', () async {
      final patientToken = createFakeJwt({'Role': 'PATIENT'});
      await SessionHepler.saveToken(patientToken);

      var cartClearCalled = false;
      final client = MockClient((request) async {
        cartClearCalled = true;
        return http.Response.bytes(const [], 204);
      });
      final cartRepo = CartRepository(client: client, baseUrl: 'http://test.api');

      await SessionHepler.clear(cartRepository: cartRepo);

      expect(cartClearCalled, isFalse);
      expect(await SessionHepler.getToken(), isNull);
    });

    test('isAdmin() không tin user_role giả mạo và isLoggedIn() từ chối token hỏng', () async {
      SharedPreferences.setMockInitialValues({
        'user_role': 'ADMIN',
        'jwt_token': 'malformed_token',
      });

      expect(await SessionHepler.isAdmin(), isFalse);
      expect(await SessionHepler.isLoggedIn(), isFalse);
      expect(await SessionHepler.getToken(), isNull);
    });
  });
}
