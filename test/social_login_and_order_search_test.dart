import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/auth_models.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/repositories/order_repository.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';
import 'package:medical_appointment_app/screens/home/home_page.dart';
import 'package:medical_appointment_app/services/social_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

String _fakePatientJwt() {
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
            'sub': '12',
            'name': 'Lê Thanh Tính',
            'phone': 'GG_8391024',
            'Role': 'PATIENT',
            'exp': exp,
          }),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

class _FakeSocialAuthGateway implements SocialAuthGateway {
  @override
  Future<SocialLoginRequest?> authenticate(String provider) async {
    return switch (provider) {
      'Google' => const SocialLoginRequest(
        provider: 'Google',
        idToken: 'real-google-id-token',
        email: 'lethanhtinh2004@gmail.com',
        fullName: 'Lê Thanh Tính',
      ),
      'Facebook' => const SocialLoginRequest(
        provider: 'Facebook',
        accessToken: 'real-facebook-access-token',
      ),
      'Zalo' => const SocialLoginRequest(
        provider: 'Zalo',
        oauthCode: 'real-zalo-oauth-code',
        codeVerifier: 'real-pkce-verifier',
      ),
      _ => null,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Đăng nhập OAuth thật bằng Gmail / Facebook / Zalo gửi token chuẩn về Backend và vào HomePage',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Map<String, dynamic>? socialBody;
      final client = MockClient((req) async {
        if (req.url.path == '/api/auth/social-login') {
          socialBody = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'token': _fakePatientJwt(),
            'message': 'Đăng nhập bằng Google thành công!',
            'provider': socialBody!['provider'],
            'isNewUser': false,
          });
        }
        return _json({'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 10});
      });

      final authRepo = AuthRepository(
        client: client,
        baseUrl: 'http://test.api',
        token: () async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LoginPage(
            authRepository: authRepo,
            socialAuthGateway: _FakeSocialAuthGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('social-login-google-btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-login-facebook-btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-login-zalo-btn')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('social-login-google-btn')));
      await tester.pumpAndSettle();

      expect(socialBody?['provider'], 'Google');
      expect(socialBody?['idToken'], 'real-google-id-token');
      expect(socialBody?['email'], 'lethanhtinh2004@gmail.com');
      expect(find.byType(HomePage), findsOneWidget);
    },
  );

  testWidgets('Tìm kiếm và lọc đơn hàng phía bệnh nhân trong OrderHistoryPage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final queryHistory = <Map<String, String>>[];
    final client = MockClient((req) async {
      if (req.url.path == '/api/orders') {
        queryHistory.add(req.url.queryParameters);
        final search = req.url.queryParameters['search'] ?? '';
        if (search == 'Minh Anh') {
          return _json({
            'items': [
              {
                'id': 25,
                'createdAt': '2026-11-26T01:00:00Z',
                'totalAmount': 200000,
                'paymentStatus': 'Paid',
                'paymentMethod': 'VNPay',
                'status': 'Confirmed',
                'totalItems': 1,
              },
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
          });
        }
        return _json({
          'items': [
            {
              'id': 10,
              'createdAt': '2026-11-25T08:00:00Z',
              'totalAmount': 150000,
              'paymentStatus': 'Unpaid',
              'paymentMethod': 'Cash',
              'status': 'Pending',
              'totalItems': 1,
            },
            {
              'id': 25,
              'createdAt': '2026-11-26T01:00:00Z',
              'totalAmount': 200000,
              'paymentStatus': 'Paid',
              'paymentMethod': 'VNPay',
              'status': 'Confirmed',
              'totalItems': 1,
            },
          ],
          'totalCount': 2,
          'page': 1,
          'pageSize': 10,
        });
      }
      return _json({}, statusCode: 404);
    });

    final repo = OrderRepository(
      apiClient: ApiClient(
        client: client,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'jwt',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: OrderHistoryPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Đơn #10'), findsOneWidget);
    expect(find.textContaining('Đơn #25'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('patient-order-search-field')),
      'Minh Anh',
    );
    await tester.tap(find.byKey(const ValueKey('patient-order-search-btn')));
    await tester.pumpAndSettle();

    expect(queryHistory.last['search'], 'Minh Anh');
    expect(find.textContaining('Đơn #10'), findsNothing);
    expect(find.textContaining('Đơn #25'), findsOneWidget);
  });
}
