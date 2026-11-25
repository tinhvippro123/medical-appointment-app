import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/helpers/api_exception.dart';
import 'package:medical_appointment_app/helpers/form_validators.dart';
import 'package:medical_appointment_app/models/auth_models.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/screens/auth/forgot_password_page.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';

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

  group('1. Card A11 Validators & AuthRepository Unit Tests', () {
    test('validateRequiredEmail và validateOtp6 kiểm tra đúng định dạng', () {
      expect(FormValidators.validateRequiredEmail(''), isNotNull);
      expect(FormValidators.validateRequiredEmail('sai-email'), isNotNull);
      expect(FormValidators.validateRequiredEmail('user@gmail.com'), isNull);

      expect(FormValidators.validateOtp6(''), isNotNull);
      expect(FormValidators.validateOtp6('12345'), isNotNull);
      expect(FormValidators.validateOtp6('12a456'), isNotNull);
      expect(FormValidators.validateOtp6('482910'), isNull);
    });

    test('forgotPasswordRequest và resetPasswordRequest xử lý thành công & lỗi API', () async {
      final capturedBodies = <String, Map<String, dynamic>>{};

      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        capturedBodies[req.url.path] = body;

        if (req.url.path == '/api/auth/forgot-password') {
          if (body['email'] == 'khongco@gmail.com') {
            return _json(
              {
                'statusCode': 400,
                'errorCode': 'EMAIL_NOT_FOUND',
                'message': 'Không tìm thấy tài khoản nào gắn với địa chỉ email này!',
              },
              statusCode: 400,
            );
          }
          return _json({
            'message': 'Mã OTP đặt lại mật khẩu đã được gửi tới email của bạn.',
            'devOtp': '482910',
          });
        }

        if (req.url.path == '/api/auth/reset-password') {
          if (body['otp'] != '482910') {
            return _json(
              {
                'statusCode': 400,
                'errorCode': 'INVALID_OR_EXPIRED_OTP',
                'message': 'Mã OTP không chính xác hoặc đã hết hạn!',
              },
              statusCode: 400,
            );
          }
          return _json({
            'message': 'Đặt lại mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.',
          });
        }

        return _json({}, statusCode: 404);
      });

      final repo = AuthRepository(
        client: mockClient,
        baseUrl: 'http://test.api',
      );

      final result = await repo.forgotPasswordRequest(
        const ForgotPasswordRequest(email: 'benhnhan@gmail.com'),
      );
      expect(result.devOtp, '482910');
      expect(capturedBodies['/api/auth/forgot-password'], {
        'email': 'benhnhan@gmail.com',
      });

      await expectLater(
        () => repo.forgotPasswordRequest(
          const ForgotPasswordRequest(email: 'khongco@gmail.com'),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'EMAIL_NOT_FOUND',
          ),
        ),
      );

      await repo.resetPasswordRequest(
        const ResetPasswordRequest(
          email: 'benhnhan@gmail.com',
          otp: '482910',
          newPassword: 'NewPassword123',
        ),
      );
      expect(capturedBodies['/api/auth/reset-password'], {
        'email': 'benhnhan@gmail.com',
        'otp': '482910',
        'newPassword': 'NewPassword123',
      });

      await expectLater(
        () => repo.resetPasswordRequest(
          const ResetPasswordRequest(
            email: 'benhnhan@gmail.com',
            otp: '000000',
            newPassword: 'NewPassword123',
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'INVALID_OR_EXPIRED_OTP',
          ),
        ),
      );
    });
  });

  group('2. Card A11 LoginPage -> ForgotPasswordPage Widget Tests', () {
    testWidgets(
      'Từ LoginPage bấm Quên mật khẩu, gửi OTP, kiểm tra validate và đặt lại mật khẩu thành công',
      (tester) async {
        configureScreenSize(tester);

        final mockClient = MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (req.url.path == '/api/auth/forgot-password') {
            return _json({
              'message': 'Mã OTP đặt lại mật khẩu đã được gửi tới email của bạn.',
              'devOtp': '654321',
            });
          }
          if (req.url.path == '/api/auth/reset-password') {
            if (body['otp'] == '654321' && body['newPassword'] == 'MatKhauMoi123') {
              return _json({
                'message': 'Đặt lại mật khẩu thành công!',
              });
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

        // Bấm Quên mật khẩu? trên LoginPage
        final forgotLink = find.byKey(
          const ValueKey('login-forgot-password-link'),
        );
        expect(forgotLink, findsOneWidget);
        await tester.tap(forgotLink);
        await tester.pumpAndSettle();

        expect(find.byType(ForgotPasswordPage), findsOneWidget);
        expect(find.text('Quên Mật Khẩu'), findsOneWidget);

        // Bấm gửi khi chưa nhập email -> báo lỗi validate
        await tester.tap(
          find.byKey(const ValueKey('forgot-password-send-otp-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Vui lòng nhập địa chỉ email'), findsOneWidget);

        // Nhập email hợp lệ và gửi OTP
        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-email-field')),
          'tinh.admin@ytehiepphuoc.vn',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot-password-send-otp-btn')),
        );
        await tester.pumpAndSettle();

        // Sang bước 2: Đặt Lại Mật Khẩu
        expect(find.text('Đặt Lại Mật Khẩu'), findsOneWidget);
        expect(find.text('Mã OTP thử nghiệm: 654321'), findsOneWidget);

        // Kiểm tra validate xác nhận mật khẩu không khớp
        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-otp-field')),
          '654321',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-new-password-field')),
          'MatKhauMoi123',
        );
        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-confirm-password-field')),
          'KhongKhop999',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot-password-submit-reset-btn')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);

        // Nhập khớp mật khẩu mới -> Đặt lại thành công & quay về LoginPage
        await tester.enterText(
          find.byKey(const ValueKey('forgot-password-confirm-password-field')),
          'MatKhauMoi123',
        );
        await tester.tap(
          find.byKey(const ValueKey('forgot-password-submit-reset-btn')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.text(
            'Đặt lại mật khẩu thành công! Vui lòng đăng nhập bằng mật khẩu mới.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
