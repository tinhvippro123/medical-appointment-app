import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/repositories/cart_repository.dart';
import 'package:medical_appointment_app/screens/cart/cart_page.dart';

Map<String, dynamic> item(int id) => {
  'id': id,
  'doctorId': 1,
  'doctorFullName': 'Bác sĩ An',
  'doctorAvatarUrl': null,
  'doctorIsActive': true,
  'departmentName': 'Nội khoa',
  'consultationFee': 150000,
  'patientProfileFullName': 'Nguyễn An',
  'appointmentDate': '2027-01-01',
  'timeSlot': '08:00-09:00',
  'note': 'Lưu ý',
};
void main() {
  testWidgets('Giỏ hàng hiển thị tổng và chỉ xóa sau xác nhận', (tester) async {
    var deletes = 0;
    final repo = CartRepository(
      baseUrl: 'http://localhost',
      token: () async => 'test',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test');
        if (request.method == 'DELETE') {
          deletes++;
          return http.Response('', 204);
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode([item(1), item(2)])),
          200,
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: CartPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('300.000 đ'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa lịch hẹn').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.byTooltip('Xóa lịch hẹn').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.text('150.000 đ'), findsNWidgets(2));
  });
  testWidgets('Giỏ rỗng hiển thị nút xem bác sĩ', (tester) async {
    final repo = CartRepository(
      baseUrl: 'http://localhost',
      token: () async => 'test',
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await tester.pumpWidget(MaterialApp(home: CartPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch hẹn nào'), findsOneWidget);
    expect(find.text('Xem bác sĩ'), findsOneWidget);
  });
  test('Sửa lịch giữ ghi chú và clear gửi đúng endpoint', () async {
    final requests = <http.Request>[];
    final repo = CartRepository(
      baseUrl: 'http://localhost',
      token: () async => 'test',
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('', 204);
      }),
    );
    await repo.update(
      CartItem.fromJson(item(3)),
      DateTime(2027, 2, 3),
      '09:00-10:00',
    );
    expect(jsonDecode(requests.first.body), {
      'appointmentDate': '2027-02-03',
      'timeSlot': '09:00-10:00',
      'note': 'Lưu ý',
    });
    await repo.clear();
    expect(requests.last.url.path, '/api/cart/clear');
    expect(requests.last.method, 'DELETE');
  });
}
