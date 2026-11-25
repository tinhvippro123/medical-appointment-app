import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/helpers/api_exception.dart';
import 'package:medical_appointment_app/models/auth_models.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'package:medical_appointment_app/screens/auth/register_page.dart';
import 'package:medical_appointment_app/screens/auth/verify_email_page.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void configureScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('1. Card A12 AuthRepository Email Verification Unit Tests', () {
    test(
      'registerRequest trả về requiresEmailVerification, verifyEmailRequest và resendVerificationOtpRequest hoạt động đúng',
      () async {
        final captured = <String, Map<String, dynamic>>{};

        final mockClient = MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          captured[req.url.path] = body;

          if (req.url.path == '/api/auth/register') {
            return _json({
              'message':
                  'Đăng ký thành công! Vui lòng nhập mã OTP gửi tới email để kích hoạt tài khoản.',
              'requiresEmailVerification': true,
              'email': body['email'],
              'devOtp': '112233',
            });
          }

          if (req.url.path == '/api/auth/verify-email') {
            if (body['otp'] != '778899') {
              return _json(
                {
                  'statusCode': 400,
                  'errorCode': 'INVALID_OR_EXPIRED_OTP',
                  'message': 'Mã OTP không chính xác hoặc đã hết hạn!',
                },
                statusCode: 400,
              );
            }
            return _json({'message': 'Xác thực email thành công!'});
          }

          if (req.url.path == '/api/auth/resend-verify-email') {
            return _json({
              'message': 'Đã gửi lại mã OTP xác thực tới email của bạn.',
              'devOtp': '778899',
            });
          }

          return _json({}, statusCode: 404);
        });

        final repo = AuthRepository(
          client: mockClient,
          baseUrl: 'http://test.api',
        );

        final regResult = await repo.registerRequest(
          RegisterRequest(
            fullName: 'Trần Minh Khôi',
            phone: '0911222333',
            email: 'khoi@gmail.com',
            password: 'Password123',
          ),
        );
        expect(regResult.requiresEmailVerification, isTrue);
        expect(regResult.email, 'khoi@gmail.com');
        expect(regResult.devOtp, '112233');

        await expectLater(
          () => repo.verifyEmailRequest(
            const VerifyEmailRequest(email: 'khoi@gmail.com', otp: '000000'),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.errorCode,
              'errorCode',
              'INVALID_OR_EXPIRED_OTP',
            ),
          ),
        );

        final resent = await repo.resendVerificationOtpRequest('khoi@gmail.com');
        expect(resent.devOtp, '778899');

        await repo.verifyEmailRequest(
          const VerifyEmailRequest(email: 'khoi@gmail.com', otp: '778899'),
        );
        expect(captured['/api/auth/verify-email'], {
          'email': 'khoi@gmail.com',
          'otp': '778899',
        });
      },
    );
  });

  group('2. Card A12 RegisterPage -> VerifyEmailPage -> LoginPage Widget Tests', () {
    testWidgets(
      'Đăng ký tài khoản mới gửi kèm Email -> mở VerifyEmailPage -> gửi lại OTP & xác thực kích hoạt thành công',
      (tester) async {
        configureScreenSize(tester);

        var activeOtp = '246810';
        final mockClient = MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;

          if (req.url.path == '/api/auth/register') {
            return _json({
              'message':
                  'Đăng ký thành công! Vui lòng nhập mã OTP gửi tới email để kích hoạt tài khoản.',
              'requiresEmailVerification': true,
              'email': body['email'],
              'devOtp': activeOtp,
            });
          }

          if (req.url.path == '/api/auth/resend-verify-email') {
            activeOtp = '135790';
            return _json({
              'message': 'Đã gửi lại mã OTP xác thực tới email của bạn.',
              'devOtp': activeOtp,
            });
          }

          if (req.url.path == '/api/auth/verify-email') {
            if (body['otp'] == activeOtp) {
              return _json({'message': 'Xác thực email thành công!'});
            }
            return _json(
              {
                'statusCode': 400,
                'errorCode': 'INVALID_OR_EXPIRED_OTP',
                'message': 'Mã OTP không chính xác hoặc đã hết hạn!',
              },
              statusCode: 400,
            );
          }

          return _json({}, statusCode: 404);
        });

        final repo = AuthRepository(
          client: mockClient,
          baseUrl: 'http://test.api',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: LoginPage(authRepository: repo),
          ),
        );
        await tester.pumpAndSettle();

        // Từ LoginPage chuyển sang RegisterPage (truyền repo trực tiếp bằng test route)
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterPage(authRepository: repo),
                      ),
                    ),
                    child: const Text('Mở đăng ký'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mở đăng ký'));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterPage), findsOneWidget);

        // Nhập đầy đủ Họ tên, Email, SĐT, Mật khẩu, Xác nhận
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Họ và tên bệnh nhân'),
          'Nguyễn Minh Thư',
        );
        await tester.enterText(
          find.byKey(const ValueKey('register-email-field')),
          'minhthu@gmail.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Số điện thoại'),
          '0988777666',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Mật khẩu'),
          'MatKhau123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Xác nhận lại mật khẩu'),
          'MatKhau123',
        );

        await tester.tap(find.text('ĐĂNG KÝ NGAY'));
        await tester.pumpAndSettle();

        // Tự động chuyển sang VerifyEmailPage
        expect(find.byType(VerifyEmailPage), findsOneWidget);
        expect(find.text('Xác Thực Email'), findsOneWidget);
        expect(find.text('Mã OTP thử nghiệm: 246810'), findsOneWidget);

        // Thử bấm gửi lại OTP -> cập nhật mã mới 135790
        await tester.tap(
          find.byKey(const ValueKey('verify-email-resend-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mã OTP thử nghiệm: 135790'), findsOneWidget);

        // Nhập đúng mã OTP -> kích hoạt thành công và tự pop hết về màn gốc
        await tester.enterText(
          find.byKey(const ValueKey('verify-email-otp-field')),
          '135790',
        );
        await tester.tap(
          find.byKey(const ValueKey('verify-email-submit-btn')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VerifyEmailPage), findsNothing);
        expect(find.byType(RegisterPage), findsNothing);
        expect(
          find.text(
            'Xác thực email thành công! Tài khoản đã được kích hoạt, hãy đăng nhập.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
