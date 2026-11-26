import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/widgets/admin_route_guard.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/repositories/order_repository.dart';
import 'package:medical_appointment_app/repositories/patient_profile_repository.dart';
import 'package:medical_appointment_app/screens/booking/booking_page.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';

http.Response _jsonResp(Object body, {int statusCode = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  testWidgets('AdminRouteGuard chặn người dùng thường và cho phép ADMIN', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminRouteGuard(
          key: const ValueKey('guard-denied'),
          isAdminChecker: () async => false,
          child: const Scaffold(body: Text('Màn hình quản trị bí mật')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
    expect(find.text('Màn hình quản trị bí mật'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminRouteGuard(
          key: const ValueKey('guard-allowed'),
          isAdminChecker: () async => true,
          child: const Scaffold(body: Text('Màn hình quản trị bí mật')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Màn hình quản trị bí mật'), findsOneWidget);
  });

  test('ApiClient kích hoạt onUnauthorizedCallback khi gặp 401 có token', () async {
    var unauthorizedCount = 0;
    final client = ApiClient(
      baseUrl: 'http://test.api',
      tokenProvider: () async => 'expired.jwt.token',
      onUnauthorizedCallback: () async => unauthorizedCount++,
      client: MockClient(
        (_) async => _jsonResp({'message': 'Token hết hạn'}, statusCode: 401),
      ),
    );

    await expectLater(
      () => client.get('/api/orders'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(unauthorizedCount, 1);
  });

  test(
    'DepartmentRepository đọc được ValidationProblemDetails.errors qua ApiClient',
    () async {
      final repo = DepartmentRepository(
        baseUrl: 'http://test.api',
        token: () async => 'jwt',
        client: MockClient(
          (_) async => _jsonResp({
            'title': 'One or more validation errors occurred.',
            'errors': {
              'Name': ['Vui lòng nhập tên chuyên khoa'],
            },
          }, statusCode: 400),
        ),
      );

      await expectLater(
        () => repo.save(name: '', description: '', consultationFee: 100000),
        throwsA(
          isA<ApiException>().having(
            (e) => e.displayMessage,
            'displayMessage',
            contains('Vui lòng nhập tên chuyên khoa'),
          ),
        ),
      );
    },
  );

  testWidgets(
    'BookingPage tự hiện lịch chọn ngày khi initialDate trúng ngày bác sĩ nghỉ',
    (tester) async {
      // 2026-12-07 là Thứ 2 (DayOfWeek = 1)
      final now = DateTime.utc(2026, 12, 7, 1, 0); // 08:00 VN
      final dayOffDate = DateTime(2026, 12, 8); // Thứ 3 (DayOfWeek = 2)

      final mockClient = MockClient((req) async {
        if (req.url.path == '/api/doctors/1') {
          return _jsonResp({
            'id': 1,
            'fullName': 'BS. Nguyễn Văn A',
            'departmentId': 1,
            'departmentName': 'Nội tổng quát',
            'experienceYears': 10,
            'consultationFee': 150000,
            'isActive': true,
            'schedules': [
              {
                'id': 1,
                'dayOfWeek': 1,
                'startTime': '08:00:00',
                'endTime': '11:00:00',
                'maxPatients': 10,
              },
              {
                'id': 2,
                'dayOfWeek': 2,
                'startTime': '08:00:00',
                'endTime': '11:00:00',
                'maxPatients': 10,
              },
              {
                'id': 3,
                'dayOfWeek': 3,
                'startTime': '08:00:00',
                'endTime': '11:00:00',
                'maxPatients': 10,
              },
            ],
          });
        }
        if (req.url.path == '/api/doctors/1/day-offs') {
          return _jsonResp([
            {'id': 10, 'doctorId': 1, 'date': '2026-12-08', 'reason': 'Nghỉ phép'},
          ]);
        }
        if (req.url.path == '/api/patient-profiles') {
          return _jsonResp([
            {
              'id': 5,
              'fullName': 'Bệnh nhân A',
              'dateOfBirth': '1999-01-01',
              'gender': 'Nam',
              'relationship': 'Bản thân',
            },
          ]);
        }
        return _jsonResp({}, statusCode: 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.api',
        client: mockClient,
        tokenProvider: () async => 'token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BookingPage(
            doctorId: 1,
            initialDate: dayOffDate,
            nowProvider: () => now,
            isLoggedIn: () async => true,
            doctorRepository: DoctorRepository(apiClient: apiClient),
            patientProfileRepository: PatientProfileRepository(
              apiClient: apiClient,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dù có initialDate nhưng trúng ngày nghỉ -> CalendarDatePicker phải hiện để người dùng đổi ngày
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.text('Bác sĩ nghỉ vào ngày đã chọn.'), findsOneWidget);
    },
  );

  testWidgets('OrderHistoryPage hiển thị đúng thông báo lỗi ApiException', (
    tester,
  ) async {
    final repo = OrderRepository(
      apiClient: ApiClient(
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
        client: MockClient(
          (_) async => _jsonResp(
            {'message': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'},
            statusCode: 401,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OrderHistoryPage(repository: repo))),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
  });
}
