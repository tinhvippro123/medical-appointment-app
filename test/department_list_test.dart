import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/department.dart';
import 'package:medical_appointment_app/models/patient_profile.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/screens/departments/department_list_page.dart';
import 'package:medical_appointment_app/screens/doctors/search/doctor_search_page.dart';

void main() {
  testWidgets('Chọn chuyên khoa và tìm bác sĩ trong khoa đó', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final Object data = switch (request.url.path) {
        '/api/departments' => [
          {'id': 2, 'name': 'Tim mạch'},
          {'id': 7, 'name': 'Nhi khoa'},
        ],
        '/api/departments/7/doctors' || '/api/doctors/search' => {
          'items': [],
          'page': 1,
          'pageSize': 10,
          'totalPages': 0,
          'totalCount': 0,
        },
        _ => throw StateError('Unexpected request ${request.url}'),
      };
      return http.Response.bytes(utf8.encode(jsonEncode(data)), 200);
    });
    addTearDown(client.close);
    final departments = DepartmentRepository(
      client: client,
      baseUrl: 'http://test.api',
      token: () async => null,
    );
    final doctors = DoctorRepository(
      apiClient: ApiClient(
        client: client,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DepartmentListPage(repository: departments),
        routes: {
          '/doctors': (context) => DoctorSearchPage(
            browse: true,
            department:
                ModalRoute.of(context)!.settings.arguments as Department,
            repository: doctors,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Tim mạch'), findsOneWidget);
    await tester.tap(find.text('Nhi khoa'));
    await tester.pumpAndSettle();
    expect(find.text('Nhi khoa'), findsOneWidget);
    expect(find.text('Chuyên khoa này chưa có bác sĩ.'), findsOneWidget);
    expect(requests.first.path, '/api/departments');
    expect(requests.last.path, '/api/departments/7/doctors');
    expect(requests.last.queryParameters['page'], '1');

    await tester.enterText(find.byType(TextField), 'An');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['keyword'], 'An');
    expect(requests.last.queryParameters['departmentId'], '7');
  });

  testWidgets('Đặt khám từ chuyên khoa mở lịch trước khi chọn bác sĩ', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode('[{"id":7,"name":"Nhi khoa"}]'),
        200,
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DepartmentListPage(
          repository: DepartmentRepository(
            client: client,
            baseUrl: 'http://test.api',
            token: () async => null,
          ),
          patient: const PatientProfile(
            id: 1,
            fullName: 'Trần Bé Bình',
            relationship: 'Con',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhi khoa'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn ngày khám'), findsOneWidget);
    expect(find.text('Trần Bé Bình (Con)'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Chọn bác sĩ'), findsOneWidget);
    expect(find.byType(DoctorSearchPage), findsNothing);
  });
}
