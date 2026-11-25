import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/order.dart';
import 'package:medical_appointment_app/repositories/payment_repository.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';
import 'package:medical_appointment_app/screens/payment/online_payment_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

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

  const sampleUnpaidOrder = Order(
    id: 18,
    userId: 4,
    userFullName: 'Lê Thanh Tính',
    totalAmount: 200000,
    status: 'Pending',
    paymentMethod: 'VNPay',
    paymentStatus: 'Unpaid',
  );

  group('1. Card D10 PaymentRepository Unit Tests', () {
    test('Khởi tạo phiên VNPay và xác thực chữ ký callback thành công', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/payments/vnpay') {
          return _json({
            'orderId': 18,
            'amount': 200000,
            'txnRef': 'VNP18_20261125',
            'paymentUrl':
                'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_SecureHash=abc',
            'callbackSuccessUrl':
                'http://test.api/api/payments/callback?vnp_ResponseCode=00&vnp_SecureHash=abc',
            'callbackCancelUrl':
                'http://test.api/api/payments/callback?vnp_ResponseCode=24&vnp_SecureHash=def',
          });
        }
        if (req.url.path == '/api/payments/callback') {
          final code = req.url.queryParameters['vnp_ResponseCode'];
          return _json({
            'success': code == '00',
            'orderId': 18,
            'paymentMethod': 'VNPay',
            'paymentStatus': code == '00' ? 'Paid' : 'Unpaid',
            'transactionId': '14250001',
            'responseCode': code ?? '99',
            'message': code == '00' ? 'Thanh toán thành công!' : 'Đã hủy',
          });
        }
        return _json({}, statusCode: 404);
      });

      final repo = PaymentRepository(
        apiClient: ApiClient(
          client: client,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'jwt',
        ),
      );

      final vnp = await repo.createVnPay(18);
      expect(vnp.paymentUrl, contains('vnp_SecureHash='));
      expect(vnp.amountFormatted, '200.000 đ');

      final cbOk = await repo.verifyVnPayCallbackUrl(vnp.callbackSuccessUrl);
      expect(cbOk.success, isTrue);
      expect(cbOk.paymentStatus, 'Paid');
    });
  });

  group('2. Card D10 OrderInfo -> VNPay Card + OTP Widget Tests', () {
    testWidgets(
      'Không có quét mã QR, bắt buộc nhập số thẻ ATM + tên chủ thẻ + ngày phát hành + OTP 123456 mới hoàn tất thanh toán VNPay',
      (tester) async {
        configureScreenSize(tester);

        final client = MockClient((req) async {
          if (req.url.path == '/api/payments/vnpay') {
            return _json({
              'orderId': 18,
              'amount': 200000,
              'txnRef': 'VNP18_20261125',
              'paymentUrl':
                  'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_SecureHash=abc',
              'callbackSuccessUrl':
                  'http://test.api/api/payments/callback?vnp_ResponseCode=00&vnp_SecureHash=abc',
              'callbackCancelUrl':
                  'http://test.api/api/payments/callback?vnp_ResponseCode=24&vnp_SecureHash=def',
            });
          }
          if (req.url.path == '/api/payments/callback') {
            final code = req.url.queryParameters['vnp_ResponseCode'];
            final ok = code == '00';
            return _json({
              'success': ok,
              'orderId': 18,
              'paymentMethod': 'VNPay',
              'paymentStatus': ok ? 'Paid' : 'Unpaid',
              'transactionId': ok ? 'VNP_TX_999' : null,
              'responseCode': code ?? '24',
              'message': ok
                  ? 'Thanh toán qua VNPay thành công!'
                  : 'Giao dịch thanh toán VNPay không thành công hoặc đã bị hủy.',
            });
          }
          return _json({}, statusCode: 404);
        });

        final paymentRepo = PaymentRepository(
          apiClient: ApiClient(
            client: client,
            baseUrl: 'http://test.api',
            tokenProvider: () async => 'jwt',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: OrderInfo(
                order: sampleUnpaidOrder,
                paymentRepository: paymentRepo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('VNPay · Chưa thanh toán'), findsOneWidget);

        // Mở màn Thanh toán trực tuyến qua VNPay
        await tester.tap(find.byKey(const ValueKey('open-online-payment-btn')));
        await tester.pumpAndSettle();

        expect(find.byType(OnlinePaymentPage), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
        expect(find.text('Cổng thanh toán VNPay'), findsOneWidget);

        // Chưa nhập số thẻ mà bấm Tiếp tục -> báo lỗi bắt buộc nhập thẻ
        await tester.tap(find.byKey(const ValueKey('vnpay-card-continue-btn')));
        await tester.pumpAndSettle();
        expect(
          find.text('Vui lòng nhập số thẻ ATM hợp lệ (từ 16 đến 19 chữ số).'),
          findsOneWidget,
        );

        // Thử bấm Hủy giao dịch -> hiện màn hình Thất bại -> bấm Thử lại
        await tester.tap(find.byKey(const ValueKey('payment-simulate-fail-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Thanh toán chưa hoàn tất'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('payment-retry-btn')));
        await tester.pumpAndSettle();

        // Nhập số thẻ ATM, chủ thẻ, ngày phát hành -> Tiếp tục sang bước OTP
        await tester.enterText(
          find.byKey(const ValueKey('vnpay-card-number-field')),
          '9704198526191432198',
        );
        await tester.enterText(
          find.byKey(const ValueKey('vnpay-card-holder-field')),
          'LE THANH TINH',
        );
        await tester.enterText(
          find.byKey(const ValueKey('vnpay-issue-date-field')),
          '0715',
        );
        await tester.tap(find.byKey(const ValueKey('vnpay-card-continue-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Xác thực giao dịch (OTP)'), findsOneWidget);
        expect(find.text('9704 **** **** 2198'), findsOneWidget);

        // Nhập OTP sai -> báo lỗi không cho qua
        await tester.enterText(
          find.byKey(const ValueKey('vnpay-otp-field')),
          '000000',
        );
        await tester.tap(
          find.byKey(const ValueKey('payment-confirm-success-btn')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Mã OTP không chính xác!'),
          findsOneWidget,
        );

        // Nhập đúng OTP 123456 -> Xác nhận thanh toán thành công
        await tester.enterText(
          find.byKey(const ValueKey('vnpay-otp-field')),
          '123456',
        );
        await tester.tap(
          find.byKey(const ValueKey('payment-confirm-success-btn')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thanh toán thành công!'), findsOneWidget);
        expect(find.text('VNP_TX_999'), findsOneWidget);

        // Bấm Hoàn tất -> quay về OrderInfo và cập nhật thành Đã thanh toán
        await tester.tap(find.byKey(const ValueKey('payment-done-return-btn')));
        await tester.pumpAndSettle();

        expect(find.text('VNPay · Đã thanh toán'), findsOneWidget);
        expect(find.text('Mã giao dịch: VNP_TX_999'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('open-online-payment-btn')),
          findsNothing,
        );
      },
    );
  });
}
