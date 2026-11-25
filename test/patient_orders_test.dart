import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/models/patient_profile.dart';
import 'package:medical_appointment_app/repositories/order_repository.dart';
import 'package:medical_appointment_app/screens/booking/checkout_page.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('Checkout tạo đơn và lịch sử hiển thị đúng mã phiếu', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final order = {
      'id': 9,
      'createdAt': '2026-11-25T08:00:00Z',
      'totalAmount': 150000,
      'paymentStatus': 'Unpaid',
      'paymentMethod': 'VietQR',
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
      final data = switch (request.url.path) {
        '/api/orders/checkout' || '/api/orders/9' => detail,
        '/api/orders' => {
          'items': [order],
          'totalCount': 1,
          'page': 1,
          'pageSize': 10,
        },
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
      return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
    });
    addTearDown(client.close);
    final repo = OrderRepository(
      apiClient: ApiClient(
        client: client,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'test-token',
      ),
    );
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
    await tester.ensureVisible(find.text('VietQR'));
    await tester.tap(find.text('VietQR'));
    final confirm = find.text('Xác nhận đặt lịch');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(requests.single.method, 'POST');
    expect(jsonDecode(requests.single.body), {
      'paymentMethod': 'VietQR',
      'appointment': {
        'doctorId': 15,
        'patientProfileId': 12,
        'appointmentDate': '2026-11-27',
        'timeSlot': '09:00-10:00',
      },
    });
    expect(find.text('Đặt lịch thành công!'), findsOneWidget);
    expect(find.text('Phòng P402'), findsOneWidget);
    expect(find.text('VietQR · Chưa thanh toán'), findsOneWidget);

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
    expect(requests.map((r) => r.url.path), [
      '/api/orders/checkout',
      '/api/orders',
      '/api/orders/9',
    ]);
  });
}
