import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/department.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/screens/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Trang chủ hiển thị Chuyên khoa khám và Đội ngũ bác sĩ mới có phân trang',
    (tester) async {
      Department? tappedDepartment;
      int? tappedDoctorId;

      final deptRepo = DepartmentRepository(
        baseUrl: 'http://test.api',
        token: () async => null,
        client: MockClient((request) async {
          if (request.url.path == '/api/departments') {
            return _json([
              {
                'id': 1,
                'name': 'Khoa Tim mạch',
                'description': 'Khám tim mạch',
                'consultationFee': 180000,
                'imageUrl': null,
              },
              {
                'id': 2,
                'name': 'Khoa Nhi',
                'description': 'Khám nhi',
                'consultationFee': 150000,
                'imageUrl': null,
              },
            ]);
          }
          return http.Response('Not Found', 404);
        }),
      );

      final doctorRepo = DoctorRepository(
        apiClient: ApiClient(
          baseUrl: 'http://test.api',
          client: MockClient((request) async {
            if (request.url.path == '/api/doctors') {
              final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
              if (page == 1) {
                return _json({
                  'items': [
                    {
                      'id': 11,
                      'fullName': 'Nguyễn Văn Mới 1',
                      'qualification': 'BS.CKI',
                      'departmentId': 1,
                      'departmentName': 'Khoa Tim mạch',
                      'experienceYears': 10,
                      'consultationFee': 180000,
                      'isActive': true,
                    },
                  ],
                  'totalCount': 2,
                  'page': 1,
                  'pageSize': 1,
                  'totalPages': 2,
                  'hasPreviousPage': false,
                  'hasNextPage': true,
                });
              }
              return _json({
                'items': [
                  {
                    'id': 12,
                    'fullName': 'Trần Thị Mới 2',
                    'qualification': 'ThS.BS',
                    'departmentId': 2,
                    'departmentName': 'Khoa Nhi',
                    'experienceYears': 6,
                    'consultationFee': 150000,
                    'isActive': true,
                  },
                ],
                'totalCount': 2,
                'page': 2,
                'pageSize': 1,
                'totalPages': 2,
                'hasPreviousPage': true,
                'hasNextPage': false,
              });
            }
            return http.Response('Not Found', 404);
          }),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomePage(
            departmentRepository: deptRepo,
            doctorRepository: doctorRepo,
          ),
          routes: {
            '/doctors': (context) {
              tappedDepartment =
                  ModalRoute.of(context)?.settings.arguments as Department?;
              return Scaffold(
                appBar: AppBar(title: const Text('Danh sách bác sĩ theo khoa')),
                body: const Text('Danh sách bác sĩ theo khoa'),
              );
            },
            '/doctors/detail': (context) {
              tappedDoctorId =
                  ModalRoute.of(context)?.settings.arguments as int?;
              return Scaffold(
                appBar: AppBar(title: const Text('Chi tiết bác sĩ')),
                body: const Text('Chi tiết bác sĩ'),
              );
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hiện mục Chuyên khoa khám & Đội ngũ bác sĩ mới
      final deptCard = find.byKey(const ValueKey('home-department-card-1'));
      await tester.ensureVisible(deptCard);
      expect(find.text('Chuyên khoa khám'), findsOneWidget);
      expect(find.text('Khoa Tim mạch'), findsWidgets);

      final doctor1 = find.byKey(const ValueKey('home-doctor-card-11'));
      await tester.ensureVisible(doctor1);
      expect(find.text('Đội ngũ bác sĩ mới'), findsOneWidget);
      expect(find.text('BS.CKI Nguyễn Văn Mới 1'), findsOneWidget);
      expect(find.text('Hiển thị 1 / 2 bác sĩ'), findsOneWidget);

      // 2. Bấm Xem thêm bác sĩ -> tải trang 2
      final loadMore = find.byKey(const ValueKey('home-doctors-load-more-btn'));
      await tester.ensureVisible(loadMore);
      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      expect(find.text('ThS.BS Trần Thị Mới 2'), findsOneWidget);
      expect(find.text('Hiển thị 2 / 2 bác sĩ'), findsOneWidget);
      expect(loadMore, findsNothing);

      // 3. Bấm bác sĩ -> mở chi tiết bác sĩ
      final doctor2 = find.byKey(const ValueKey('home-doctor-card-12'));
      await tester.ensureVisible(doctor2);
      await tester.tap(doctor2);
      await tester.pumpAndSettle();
      expect(tappedDoctorId, 12);

      // Quay lại bấm chuyên khoa -> mở danh sách bác sĩ theo khoa
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(deptCard);
      await tester.tap(deptCard);
      await tester.pumpAndSettle();
      expect(tappedDepartment?.id, 1);
    },
  );
}
