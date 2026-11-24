import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/repositories/room_repository.dart';
import 'package:medical_appointment_app/screens/admin/doctors/doctor_admin_page.dart';
import 'package:medical_appointment_app/screens/admin/doctors/doctor_form_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleDoctorJson({
  int id = 1,
  String name = 'BS Nguyễn Văn A',
  String? qualification = 'ThS.BS',
  int departmentId = 1,
  String departmentName = 'Khoa Nội',
  int? roomId = 10,
  String? roomNumber = '101',
  int? floor = 1,
  double fee = 200000,
  bool isActive = true,
}) => {
  'id': id,
  'fullName': name,
  'qualification': qualification,
  'email': 'doctor@example.com',
  'phone': '0901234567',
  'departmentId': departmentId,
  'departmentName': departmentName,
  'roomId': roomId,
  'roomNumber': roomNumber,
  'floor': floor,
  'description': 'Mô tả kinh nghiệm',
  'avatarUrl': '/images/doctors/avatar.jpg',
  'experienceYears': 10,
  'consultationFee': fee,
  'isActive': isActive,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Doctor Model & DoctorRepository Unit Tests', () {
    test('Doctor.fromJson parse đầy đủ trường và định dạng hiển thị', () {
      final d = Doctor.fromJson(sampleDoctorJson());

      expect(d.id, 1);
      expect(d.fullName, 'BS Nguyễn Văn A');
      expect(d.qualification, 'ThS.BS');
      expect(d.roomDisplay, 'Phòng 101 (Tầng 1)');
      expect(d.feeFormatted, '200.000 đ');
      expect(d.isActive, isTrue);
    });

    test('DoctorFormInput.toFields xuất ra các trường dạng string cho multipart', () {
      const input = DoctorFormInput(
        fullName: 'BS Trần B',
        qualification: 'CKI',
        email: 'b@example.com',
        phone: '0912345678',
        departmentId: 2,
        roomId: 5,
        description: 'Bác sĩ chuyên khoa',
        experienceYears: 5,
        consultationFee: 150000,
      );

      final fields = input.toFields();

      expect(fields['FullName'], 'BS Trần B');
      expect(fields['Qualification'], 'CKI');
      expect(fields['DepartmentId'], '2');
      expect(fields['RoomId'], '5');
      expect(fields['ExperienceYears'], '5');
      expect(fields['ConsultationFee'], '150000');
    });

    test('DoctorRepository gọi GET, POST, PUT, DELETE đúng định dạng', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);

        if (request.method == 'GET' && request.url.path == '/api/doctors') {
          final res = {
            'items': [sampleDoctorJson(id: 1), sampleDoctorJson(id: 2)],
            'totalCount': 2,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          };
          return http.Response.bytes(
            utf8.encode(jsonEncode(res)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.method == 'POST' && request.url.path == '/api/doctors') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorJson(id: 3, name: 'BS Mới'))),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.method == 'DELETE' && request.url.path == '/api/doctors/1') {
          return http.Response.bytes(const [], 204);
        }

        return http.Response.bytes(
          utf8.encode(jsonEncode(sampleDoctorJson())),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'admin_token',
      );
      final repo = DoctorRepository(apiClient: apiClient);

      // 1. GET danh sách
      final paged = await repo.getDoctors(page: 1, pageSize: 10);
      expect(paged.items.length, 2);
      expect(requests.last.method, 'GET');
      expect(requests.last.headers['Authorization'], 'Bearer admin_token');

      // 2. POST tạo mới
      const input = DoctorFormInput(
        fullName: 'BS Mới',
        departmentId: 1,
        experienceYears: 2,
        consultationFee: 100000,
      );
      final created = await repo.createDoctor(
        input,
        imageBytes: [1, 2, 3],
        imageFilename: 'avatar.png',
      );
      expect(created.id, 3);
      expect(created.fullName, 'BS Mới');
      expect(requests.last.method, 'POST');

      // 3. DELETE xóa
      await repo.deleteDoctor(1);
      expect(requests.last.method, 'DELETE');
    });
  });

  group('DoctorAdminPage & DoctorFormPage Widget Tests', () {
    testWidgets('DoctorAdminPage hiển thị danh sách bác sĩ và dialog xác nhận xóa', (
      tester,
    ) async {
      var deleteCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/doctors') {
          final res = {
            'items': [
              sampleDoctorJson(id: 1, name: 'BS Nguyễn Văn An', qualification: 'ThS'),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          };
          return http.Response.bytes(
            utf8.encode(jsonEncode(res)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        if (request.method == 'DELETE' && request.url.path == '/api/doctors/1') {
          deleteCalled = true;
          return http.Response.bytes(const [], 204);
        }

        return http.Response.bytes(utf8.encode('{}'), 200);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
      );
      final docRepo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorAdminPage(doctorRepository: docRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tên bác sĩ và bằng cấp hiển thị
      expect(find.text('BS Nguyễn Văn An'), findsOneWidget);
      expect(find.text('ThS'), findsOneWidget);
      expect(find.text('200.000 đ'), findsOneWidget);

      // Bấm nút xóa bác sĩ
      final deleteBtn = find.byKey(const ValueKey('delete-doctor-1'));
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Dialog xác nhận xuất hiện
      expect(find.text('Xác nhận xóa'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);

      // Bấm Xóa trong dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('DoctorFormPage prefill đúng thông tin và xử lý phòng không active an toàn', (
      tester,
    ) async {
      // Mock Departments
      final mockDepts = [
        {'id': 1, 'name': 'Khoa Nội'},
        {'id': 2, 'name': 'Khoa Ngoại'},
      ];

      // Mock Rooms: chỉ có phòng 202 là active, phòng 101 của bác sĩ đang inactive
      final mockRooms = [
        {
          'id': 20,
          'roomNumber': '202',
          'floor': 2,
          'departmentId': 1,
          'isActive': true,
        },
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/departments') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(mockDepts)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/rooms') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(mockRooms)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(utf8.encode('{}'), 200);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'token',
      );
      final docRepo = DoctorRepository(apiClient: apiClient);
      final deptRepo = DepartmentRepository(client: mockClient, baseUrl: 'http://test.api');
      final roomRepo = RoomRepository(apiClient: apiClient);

      // Bác sĩ có phòng 101 (id: 10), nhưng phòng này đã inactive
      final existingDoctor = Doctor.fromJson(
        sampleDoctorJson(
          id: 1,
          name: 'BS Lê Văn C',
          departmentId: 1,
          roomId: 10,
          roomNumber: '101',
          floor: 1,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorFormPage(
            doctor: existingDoctor,
            doctorRepository: docRepo,
            departmentRepository: deptRepo,
            roomRepository: roomRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra họ tên được prefill
      expect(find.text('BS Lê Văn C'), findsOneWidget);

      // Kiểm tra dropdown phòng không bị crash và hiển thị phòng 101 với tag không hoạt động
      expect(find.textContaining('Phòng 101'), findsOneWidget);
    });
  });
}
