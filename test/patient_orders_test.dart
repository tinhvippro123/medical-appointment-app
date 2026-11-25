import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/models/patient_profile.dart';
import 'package:medical_appointment_app/repositories/order_repository.dart';
import 'package:medical_appointment_app/repositories/payment_repository.dart';
import 'package:medical_appointment_app/screens/booking/checkout_page.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';
import 'package:medical_appointment_app/screens/payment/online_payment_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets(
    'Checkout thoát giữa chừng tự xóa đơn chưa thanh toán, thanh toán xong mới xuất phiếu & xem lịch sử',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final requests = <http.Request>[];
      final order = {
        'id': 9,
        'createdAt': '2026-11-25T08:00:00Z',
        'totalAmount': 150000,
        'paymentStatus': 'Unpaid',
        'paymentMethod': 'VNPay',
        'status': 'Pending',
        'totalItems': 1,
      };
      final detail = {
        ...order,
        'orderDetails': [
          {
            'id': 83,
            'doctorFullName': 'Mai Thị Minh Tâm',
            'roomNumber': 'P402',
            'patientProfileFullName': 'Trần Minh An',
            'appointmentDate': '2026-11-27',
            'timeSlot': '09:00-10:00',
            'queueNumber': 2,
            'fee': 150000,
          },
        ],
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/orders/9/unpaid' &&
            request.method == 'DELETE') {
          return http.Response('', 204);
        }
        final data = switch (request.url.path) {
          '/api/orders/checkout' || '/api/orders/9' => detail,
          '/api/payments/vnpay' => {
            'orderId': 9,
            'amount': 150000,
            'txnRef': 'VNP9_20261125',
            'paymentUrl':
                'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_SecureHash=abc',
            'callbackSuccessUrl':
                'http://test.api/api/payments/callback?vnp_ResponseCode=00&vnp_SecureHash=abc',
            'callbackCancelUrl':
                'http://test.api/api/payments/callback?vnp_ResponseCode=24&vnp_SecureHash=def',
          },
          '/api/payments/callback' => {
            'success': true,
            'orderId': 9,
            'paymentMethod': 'VNPay',
            'paymentStatus': 'Paid',
            'transactionId': 'VNP9_PAID',
            'responseCode': '00',
            'message': 'Thanh toán qua VNPay thành công!',
          },
          '/api/orders' => {
            'items': [
              {...order, 'paymentStatus': 'Paid'},
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
          },
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
        return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
      });
      addTearDown(client.close);
      final apiClient = ApiClient(
        client: client,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'test-token',
      );
      final repo = OrderRepository(apiClient: apiClient);
      final paymentRepo = PaymentRepository(apiClient: apiClient);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CheckoutPage(
                          doctor: const Doctor(
                            id: 15,
                            fullName: 'Mai Thị Minh Tâm',
                            departmentId: 7,
                            departmentName: 'Cơ xương khớp',
                            experienceYears: 0,
                            consultationFee: 150000,
                            isActive: true,
                          ),
                          patient: const PatientProfile(
                            id: 12,
                            fullName: 'Trần Minh An',
                            relationship: 'Bản thân',
                          ),
                          date: DateTime(2026, 11, 27),
                          slot: '09:00-10:00',
                          note: '',
                          hasHealthInsurance: false,
                          repository: repo,
                          paymentRepository: paymentRepo,
                        ),
                      ),
                    ),
                    child: const Text('Checkout'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            Scaffold(body: OrderHistoryPage(repository: repo)),
                      ),
                    ),
                    child: const Text('Lịch sử'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VNPay'));
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      // Lần 1: Mở cổng VNPay nhưng bấm Back thoát ngang -> tự gọi DELETE /api/orders/9/unpaid
      expect(find.byType(OnlinePaymentPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch thành công!'), findsNothing);
      expect(
        requests.any(
          (r) => r.method == 'DELETE' && r.url.path == '/api/orders/9/unpaid',
        ),
        isTrue,
      );

      // Lần 2: Xác nhận lại và nhập thẻ ATM + OTP 123456 hoàn tất thanh toán
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('vnpay-fill-sample-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('vnpay-card-continue-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vnpay-otp-field')),
        '123456',
      );
      await tester.tap(
        find.byKey(const ValueKey('payment-confirm-success-btn')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-done-return-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Đặt lịch thành công!'), findsOneWidget);
      expect(find.text('Phòng P402'), findsOneWidget);
      expect(find.text('VNPay · Đã thanh toán'), findsOneWidget);

      await tester.tap(find.text('Về trang chủ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('1 lịch hẹn'), findsOneWidget);
      await tester.tap(find.textContaining('Đơn #9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mã QR'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        'Mã QR TICKET-83',
      );
    },
  );
}
