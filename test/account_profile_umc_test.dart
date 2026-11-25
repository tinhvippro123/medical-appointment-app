import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/user_role_models.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/screens/account/account_page.dart';
import 'package:medical_appointment_app/screens/account/personal_info_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

String _fakeJwt({required String fullName, required String phone}) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final exp =
      (DateTime.now().add(const Duration(days: 7)).toUtc().millisecondsSinceEpoch /
              1000)
          .floor();
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': '4',
            'name': fullName,
            'phone': phone,
            'Role': 'PATIENT',
            'exp': exp,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void configureScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maskPhoneNumber che đúng 4 chữ số giữa của SĐT 10 số', () {
    expect(maskPhoneNumber('0371234855'), '037****855');
    expect(maskPhoneNumber('0987654321'), '098****321');
  });

  testWidgets(
    'AccountPage giao diện UMC Care -> Nhập mật khẩu xác thực chủ tài khoản -> Cập nhật Thông tin cá nhân -> Hiện thông báo nổi',
    (tester) async {
      configureScreenSize(tester);

      Map<String, dynamic>? updatedPayload;
      final client = MockClient((req) async {
        if (req.url.path == '/api/auth/verify-password') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['password'] == '123456') {
            return _json({'verified': true});
          }
          return _json(
            {
              'statusCode': 400,
              'errorCode': 'WRONG_OLD_PASSWORD',
              'message': 'Mật khẩu cũ không chính xác!',
            },
            statusCode: 400,
          );
        }

        if (req.url.path == '/api/auth/me' && req.method == 'GET') {
          return _json({
            'id': 4,
            'fullName': 'Nguyễn Minh An',
            'phone': '0371234855',
            'email': 'an@gmail.com',
            'roleKey': 'PATIENT',
            'roleName': 'Bệnh nhân',
            'dateOfBirth': '2004-05-15',
            'gender': 'Nam',
          });
        }

        if (req.url.path == '/api/auth/me' && req.method == 'PUT') {
          updatedPayload = jsonDecode(req.body) as Map<String, dynamic>;
          final newName = updatedPayload!['fullName'] as String;
          return _json({
            'message': 'Cập nhật thông tin thành công.',
            'token': _fakeJwt(fullName: newName, phone: '0371234855'),
            'profile': {
              'id': 4,
              'fullName': newName,
              'phone': '0371234855',
              'email': updatedPayload!['email'],
              'roleKey': 'PATIENT',
              'roleName': 'Bệnh nhân',
              'dateOfBirth': '2004-05-15',
              'gender': 'Nam',
            },
          });
        }

        return _json({}, statusCode: 404);
      });

      final authRepo = AuthRepository(
        client: client,
        baseUrl: 'http://test.api',
        token: () async => _fakeJwt(
          fullName: 'Nguyễn Minh An',
          phone: '0371234855',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AccountPage(
              currentUser: const SessionUser(
                userId: 4,
                fullName: 'Nguyễn Minh An',
                phone: '0371234855',
                roleKey: 'PATIENT',
              ),
              authRepository: authRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra Header UMC Care che SĐT & các nhóm mục
      expect(find.text('037****855'), findsOneWidget);
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(find.text('Thay đổi mật khẩu'), findsOneWidget);
      expect(find.text('Nhận thông báo'), findsNothing);
      expect(find.text('Điều khoản dịch vụ'), findsOneWidget);
      expect(find.text('Phiên bản'), findsOneWidget);

      // Bấm Thông tin cá nhân -> hiện popup NHẬP MẬT KHẨU
      await tester.tap(find.byKey(const ValueKey('account-personal-info-row')));
      await tester.pumpAndSettle();

      expect(find.text('NHẬP MẬT KHẨU'), findsOneWidget);

      // Nhập mật khẩu sai -> báo lỗi ngay trong dialog
      await tester.enterText(
        find.byKey(const ValueKey('verify-owner-password-field')),
        'sai-mk',
      );
      await tester.tap(find.byKey(const ValueKey('verify-owner-continue-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Mật khẩu cũ không chính xác!'), findsOneWidget);

      // Nhập mật khẩu đúng -> mở màn Thông tin cá nhân
      await tester.enterText(
        find.byKey(const ValueKey('verify-owner-password-field')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('verify-owner-continue-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(PersonalInfoPage), findsOneWidget);
      expect(find.text('Thông tin tài khoản'), findsOneWidget);

      // Đổi Họ và tên lót = "Lê Thanh", Tên = "Tính", Email mới
      await tester.enterText(
        find.byKey(const ValueKey('personal-info-last-middle-field')),
        'Lê Thanh',
      );
      await tester.enterText(
        find.byKey(const ValueKey('personal-info-first-name-field')),
        'Tính',
      );
      await tester.enterText(
        find.byKey(const ValueKey('personal-info-email-field')),
        'lethanhtinh2004@gmail.com',
      );

      await tester.tap(find.byKey(const ValueKey('personal-info-save-btn')));
      await tester.pumpAndSettle();

      expect(updatedPayload?['fullName'], 'Lê Thanh Tính');
      expect(updatedPayload?['email'], 'lethanhtinh2004@gmail.com');

      // Quay về AccountPage -> tên mới Lê Thanh Tính + Banner xanh nổi phía trên
      expect(find.text('Lê Thanh Tính'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('account-top-success-banner')),
        findsOneWidget,
      );
      expect(find.text('Cập nhật thông tin thành công.'), findsOneWidget);

      // Cho hết timer 4s của banner để không còn pending timer
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
