import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'package:medical_appointment_app/screens/doctors/detail/doctor_detail_page.dart';
import 'package:medical_appointment_app/screens/doctors/detail/widgets/related_doctor_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleDoctorDetailJson({
  int id = 1,
  String name = 'BS Nguyễn Văn A',
  String? qualification = 'ThS.BS',
  String? email = 'doctor@example.com',
  String? phone = '0901234567',
  int departmentId = 1,
  String departmentName = 'Khoa Tim mạch',
  int? roomId = 10,
  String? roomNumber = '101',
  int? floor = 1,
  String? description = 'Bác sĩ nhiều năm kinh nghiệm điều trị tim mạch.',
  double fee = 150000,
  int experienceYears = 8,
  bool isActive = true,
  List<Map<String, dynamic>>? schedules,
}) => {
  'id': id,
  'fullName': name,
  'qualification': qualification,
  'email': email,
  'phone': phone,
  'departmentId': departmentId,
  'departmentName': departmentName,
  'roomId': roomId,
  'roomNumber': roomNumber,
  'floor': floor,
  'description': description,
  'avatarUrl': '/images/doctors/avatar.jpg',
  'experienceYears': experienceYears,
  'consultationFee': fee,
  'isActive': isActive,
  'schedules': schedules ??
      [
        {
          'id': 101,
          'dayOfWeek': 1,
          'startTime': '07:00:00',
          'endTime': '11:30:00',
          'maxPatients': 20,
        },
        {
          'id': 102,
          'dayOfWeek': 3,
          'startTime': '13:30:00',
          'endTime': '17:00:00',
          'maxPatients': 15,
        },
      ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Doctor & DoctorSchedule Model Parsing Unit Tests', () {
    test('Parse Doctor có đầy đủ room và schedules', () {
      final json = sampleDoctorDetailJson(
        roomNumber: '205',
        floor: 2,
        schedules: [
          {
            'id': 1,
            'dayOfWeek': 1,
            'startTime': '07:00:00',
            'endTime': '11:30:00',
            'maxPatients': 20,
          },
        ],
      );

      final doctor = Doctor.fromJson(json);

      expect(doctor.id, 1);
      expect(doctor.fullName, 'BS Nguyễn Văn A');
      expect(doctor.qualification, 'ThS.BS');
      expect(doctor.roomNumber, '205');
      expect(doctor.floor, 2);
      expect(doctor.roomDetailDisplay, 'Phòng 205, Tầng 2');
      expect(doctor.schedules.length, 1);

      final sched = doctor.schedules.first;
      expect(sched.id, 1);
      expect(sched.dayOfWeek, 1);
      expect(sched.dayName, 'Thứ 2');
      expect(sched.startTimeFormatted, '07:00');
      expect(sched.endTimeFormatted, '11:30');
      expect(sched.timeRangeDisplay, '07:00-11:30');
    });

    test('Parse Doctor không có room -> roomDetailDisplay trả về "Chưa cập nhật"', () {
      final json = sampleDoctorDetailJson(roomNumber: null, floor: null);
      final doctor = Doctor.fromJson(json);

      expect(doctor.roomNumber, isNull);
      expect(doctor.floor, isNull);
      expect(doctor.roomDetailDisplay, 'Chưa cập nhật');
    });

    test('Parse Doctor có roomNumber nhưng không có floor', () {
      final json = sampleDoctorDetailJson(roomNumber: 'P.102', floor: null);
      final doctor = Doctor.fromJson(json);

      expect(doctor.roomDetailDisplay, 'Phòng P.102');
    });

    test('Parse Doctor có schedules rỗng hoặc null', () {
      final jsonEmpty = sampleDoctorDetailJson(schedules: []);
      final doctorEmpty = Doctor.fromJson(jsonEmpty);
      expect(doctorEmpty.schedules, isEmpty);
      expect(doctorEmpty.groupedSchedules, isEmpty);

      final jsonNull = Map<String, dynamic>.from(sampleDoctorDetailJson())..remove('schedules');
      final doctorNull = Doctor.fromJson(jsonNull);
      expect(doctorNull.schedules, isEmpty);
      expect(doctorNull.groupedSchedules, isEmpty);
    });

    test('Parse Doctor với JSON thiếu field và null không crash', () {
      final minimalJson = <String, dynamic>{
        'id': null,
        'fullName': null,
        'consultationFee': null,
        'departmentId': null,
      };

      final doctor = Doctor.fromJson(minimalJson);
      expect(doctor.id, 0);
      expect(doctor.fullName, '');
      expect(doctor.consultationFee, 0.0);
      expect(doctor.feeFormatted, '0 đ');
      expect(doctor.roomDetailDisplay, 'Chưa cập nhật');
      expect(doctor.schedules, isEmpty);
    });

    test('DoctorSchedule.formatTime cắt giây chính xác', () {
      expect(DoctorSchedule.formatTime('07:00:00'), '07:00');
      expect(DoctorSchedule.formatTime('13:30:45'), '13:30');
      expect(DoctorSchedule.formatTime('8:5'), '08:05');
      expect(DoctorSchedule.formatTime(''), '');
    });
  });

  group('2. Gom và sắp xếp lịch theo thứ Unit Tests', () {
    test('Gom nhiều ca trong ngày và sắp xếp từ Thứ 2 đến Chủ nhật', () {
      final rawSchedules = [
        // Chủ nhật (0)
        const DoctorSchedule(
          id: 1,
          dayOfWeek: 0,
          startTime: '08:00:00',
          endTime: '11:30:00',
        ),
        // Thứ 6 (5)
        const DoctorSchedule(
          id: 2,
          dayOfWeek: 5,
          startTime: '13:30:00',
          endTime: '17:00:00',
        ),
        // Thứ 2 ca chiều (1)
        const DoctorSchedule(
          id: 3,
          dayOfWeek: 1,
          startTime: '13:30:00',
          endTime: '17:00:00',
        ),
        // Thứ 2 ca sáng (1)
        const DoctorSchedule(
          id: 4,
          dayOfWeek: 1,
          startTime: '07:00:00',
          endTime: '11:30:00',
        ),
        // Thứ 4 (3)
        const DoctorSchedule(
          id: 5,
          dayOfWeek: 3,
          startTime: '07:30:00',
          endTime: '11:30:00',
        ),
      ];

      final grouped = GroupedDoctorSchedule.groupAndSort(rawSchedules);

      // Phải có 4 nhóm: Thứ 2, Thứ 4, Thứ 6, Chủ nhật
      expect(grouped.length, 4);

      // 1. Thứ 2 (dayOfWeek: 1)
      expect(grouped[0].dayOfWeek, 1);
      expect(grouped[0].dayName, 'Thứ 2');
      // Sắp xếp ca sáng trước, ca chiều sau: 07:00-11:30, 13:30-17:00
      expect(grouped[0].timeSlotsDisplay, '07:00-11:30, 13:30-17:00');
      expect(grouped[0].fullDisplay, 'Thứ 2: 07:00-11:30, 13:30-17:00');

      // 2. Thứ 4 (dayOfWeek: 3)
      expect(grouped[1].dayOfWeek, 3);
      expect(grouped[1].dayName, 'Thứ 4');
      expect(grouped[1].timeSlotsDisplay, '07:30-11:30');

      // 3. Thứ 6 (dayOfWeek: 5)
      expect(grouped[2].dayOfWeek, 5);
      expect(grouped[2].dayName, 'Thứ 6');
      expect(grouped[2].timeSlotsDisplay, '13:30-17:00');

      // 4. Chủ nhật (dayOfWeek: 0) nằm cuối cùng
      expect(grouped[3].dayOfWeek, 0);
      expect(grouped[3].dayName, 'Chủ nhật');
      expect(grouped[3].timeSlotsDisplay, '08:00-11:30');
    });

    test('groupAndSort trả về rỗng khi schedules rỗng', () {
      final grouped = GroupedDoctorSchedule.groupAndSort(const []);
      expect(grouped, isEmpty);
    });
  });

  group('3. DoctorRepository Unit Tests với ApiClient giả', () {
    test('getDoctorById gửi đúng GET /api/doctors/{id} và parse đầy đủ schedules/room', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/doctors/10') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 10, roomNumber: '302', floor: 3))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      final doctor = await repo.getDoctorById(10);

      expect(requests.length, 1);
      expect(requests.first.method, 'GET');
      expect(requests.first.url.path, '/api/doctors/10');
      expect(doctor.id, 10);
      expect(doctor.roomDetailDisplay, 'Phòng 302, Tầng 3');
      expect(doctor.schedules.length, 2);
    });

    test('getDoctorById ném ApiException khi server trả 404 DOCTOR_NOT_FOUND', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'statusCode': 404,
            'errorCode': 'DOCTOR_NOT_FOUND',
            'message': 'Bác sĩ không tồn tại',
          })),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      expect(
        () => repo.getDoctorById(99),
        throwsA(isA<ApiException>().having((e) => e.errorCode, 'errorCode', 'DOCTOR_NOT_FOUND')),
      );
    });

    test('getRelatedDoctors gửi GET /api/doctors/{id}/related và parse PagedResult', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/doctors/10/related') {
          final res = {
            'items': [
              sampleDoctorDetailJson(id: 11, name: 'BS Liên quan 1'),
              sampleDoctorDetailJson(id: 12, name: 'BS Liên quan 2'),
            ],
            'totalCount': 2,
            'page': 1,
            'pageSize': 5,
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
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      final result = await repo.getRelatedDoctors(10, page: 1, pageSize: 5);

      expect(requests.length, 1);
      expect(requests.first.method, 'GET');
      expect(requests.first.url.path, '/api/doctors/10/related');
      expect(requests.first.url.queryParameters['page'], '1');
      expect(requests.first.url.queryParameters['pageSize'], '5');
      expect(result.items.length, 2);
      expect(result.items[0].fullName, 'BS Liên quan 1');
      expect(result.items[1].fullName, 'BS Liên quan 2');
    });
  });

  group('4. DoctorDetailPage Widget Tests: 4 Trạng thái', () {
    testWidgets('Trạng thái 1: Loading hiển thị CircularProgressIndicator', (tester) async {
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) => completer.future);
      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );

      // Đang loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Giải phóng completer
      completer.complete(http.Response.bytes(
        utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
      await tester.pumpAndSettle();
    });

    testWidgets('Trạng thái 2: Không tìm thấy (404 DOCTOR_NOT_FOUND)', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'statusCode': 404,
            'errorCode': 'DOCTOR_NOT_FOUND',
            'message': 'Không tìm thấy bác sĩ yêu cầu',
          })),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 99, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy thông tin bác sĩ'), findsOneWidget);
      expect(find.text('Bác sĩ không tồn tại hoặc đã ngừng hoạt động trong hệ thống.'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('Trạng thái 3: Lỗi và nút "Thử lại" hoạt động chính xác', (tester) async {
      var attemptCount = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          attemptCount++;
          if (attemptCount == 1) {
            return http.Response.bytes(
              utf8.encode(jsonEncode({'message': 'Lỗi máy chủ nội bộ'})),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1, name: 'BS Sau Thử Lại'))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị thông báo lỗi
      expect(find.text('Lỗi máy chủ nội bộ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Nhấn Thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(attemptCount, 2);
      expect(find.text('ThS.BS BS Sau Thử Lại'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
    });

    testWidgets('Trạng thái 4: Thành công hiển thị đầy đủ thông tin, phòng khám, lịch làm việc', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1/day-offs') {
          expect(request.url.queryParameters['from'], isNotNull);
          expect(request.url.queryParameters['to'], isNotNull);
          return http.Response(
            '[{"id":1,"doctorId":1,"date":"2026-12-02"}]',
            200,
          );
        }
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(
              id: 1,
              name: 'Trần Thị B',
              qualification: 'CKII',
              phone: '0988776655',
              email: 'tranthib@gmail.com',
              roomNumber: '402',
              floor: 4,
              fee: 250000,
              experienceYears: 15,
              schedules: [
                {
                  'id': 1,
                  'dayOfWeek': 1,
                  'startTime': '07:00:00',
                  'endTime': '11:30:00',
                  'maxPatients': 20,
                },
              ],
            ))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('CKII Trần Thị B'), findsOneWidget);

      // Section thông tin
      expect(find.text('Khoa Tim mạch'), findsWidgets);
      expect(find.text('15 năm'), findsOneWidget);
      expect(find.text('250.000 đ'), findsOneWidget);
      expect(find.text('0988776655'), findsOneWidget);
      expect(find.text('tranthib@gmail.com'), findsOneWidget);

      // Section phòng khám
      expect(find.text('Phòng 402, Tầng 4'), findsOneWidget);

      // Section lịch làm việc
      expect(find.text('Thứ 2'), findsOneWidget);
      expect(find.text('07:00-11:30'), findsOneWidget);
      expect(find.text('Lịch nghỉ sắp tới'), findsOneWidget);
      expect(find.text('Thứ 4 · 02/12/2026'), findsOneWidget);

      // Nút Đặt lịch khám
      expect(find.text('Đặt lịch khám'), findsOneWidget);
    });
  });

  group('5. Bác sĩ liên quan Widget Tests', () {
    testWidgets('Danh sách related rỗng thì ẩn hoàn toàn section', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Tiêu đề 'Bác sĩ liên quan' bị ẩn hoàn toàn
      expect(find.text('Bác sĩ liên quan'), findsNothing);
      expect(find.byType(RelatedDoctorCard), findsNothing);
    });

    testWidgets('Danh sách related có dữ liệu thì hiển thị card và cho phép điều hướng', (tester) async {
      Object? capturedDetailArg;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'items': [
                sampleDoctorDetailJson(id: 5, name: 'BS Liên Quan 5', experienceYears: 7),
              ],
              'totalCount': 1,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
          routes: {
            '/doctors/detail': (context) {
              capturedDetailArg = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Trang chi tiết bác sĩ mới'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị section 'Bác sĩ liên quan'
      expect(find.text('Bác sĩ liên quan'), findsOneWidget);
      expect(find.byType(RelatedDoctorCard), findsOneWidget);
      expect(find.text('7 năm KN'), findsOneWidget);

      // Cuộn đến card bác sĩ liên quan và bấm
      await tester.ensureVisible(find.byType(RelatedDoctorCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RelatedDoctorCard));
      await tester.pumpAndSettle();

      expect(capturedDetailArg, 5);
      expect(find.text('Trang chi tiết bác sĩ mới'), findsOneWidget);
    });

    testWidgets('Lỗi tải related không làm hỏng cả trang, chỉ hiện thông báo nhỏ và nút thử lại', (tester) async {
      var relatedAttempts = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          relatedAttempts++;
          if (relatedAttempts == 1) {
            return http.Response.bytes(
              utf8.encode(jsonEncode({'message': 'Lỗi mạng khi tải liên quan'})),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'items': [sampleDoctorDetailJson(id: 8, name: 'BS Khôi Phục')],
              'totalCount': 1,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Trang chính vẫn hiển thị tốt
      expect(find.text('Khoa Tim mạch'), findsWidgets);
      // Khu vực related hiển thị lỗi cục bộ
      expect(find.text('Không thể tải bác sĩ liên quan'), findsOneWidget);

      // Cuộn đến nút thử lại trong khu vực related và bấm
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(relatedAttempts, 2);
      expect(find.text('Không thể tải bác sĩ liên quan'), findsNothing);
      expect(find.byType(RelatedDoctorCard), findsOneWidget);
    });

    testWidgets('Bác sĩ liên quan hỗ trợ tải phân trang trang 2 khi bấm Xem thêm', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
          if (page == 1) {
            return http.Response.bytes(
              utf8.encode(jsonEncode({
                'items': [
                  sampleDoctorDetailJson(id: 2, name: 'BS Liên Quan Trang 1'),
                ],
                'totalCount': 2,
                'page': 1,
                'pageSize': 1,
                'totalPages': 2,
                'hasPreviousPage': false,
                'hasNextPage': true,
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'items': [
                sampleDoctorDetailJson(id: 3, name: 'BS Liên Quan Trang 2'),
              ],
              'totalCount': 2,
              'page': 2,
              'pageSize': 1,
              'totalPages': 2,
              'hasPreviousPage': true,
              'hasNextPage': false,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('BS Liên Quan Trang 1'), findsOneWidget);
      final loadMoreBtn = find.byKey(const ValueKey('related-doctors-load-more-btn'));
      expect(loadMoreBtn, findsOneWidget);

      await tester.ensureVisible(loadMoreBtn);
      await tester.tap(loadMoreBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('BS Liên Quan Trang 2'), findsOneWidget);
      expect(loadMoreBtn, findsNothing);
    });
  });

  group('6. Nút "Đặt lịch khám" Widget Tests', () {
    testWidgets('Chưa đăng nhập -> hiện SnackBar yêu cầu và điều hướng sang LoginPage', (tester) async {
      SharedPreferences.setMockInitialValues({}); // không có jwt_token

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút Đặt lịch khám
      await tester.tap(find.text('Đặt lịch khám'));
      await tester.pumpAndSettle();

      // Kiểm tra chuyển sang màn hình LoginPage
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Vui lòng đăng nhập để đặt lịch khám'), findsOneWidget);
    });

    testWidgets('Đã đăng nhập và route /booking chưa có -> hiện SnackBar "Chức năng đang phát triển" không crash', (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'valid_token_123'});

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút Đặt lịch khám
      await tester.tap(find.text('Đặt lịch khám'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Không crash và hiện thông báo SnackBar
      expect(find.text('Chức năng đang phát triển'), findsOneWidget);
    });

    testWidgets('Đã đăng nhập và route /booking đã đăng ký -> điều hướng sang /booking với arguments doctorId', (tester) async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'valid_token_123'});
      Object? capturedBookingDoctorId;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(sampleDoctorDetailJson(id: 1))),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/doctors/1/related') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'items': [], 'totalCount': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(doctorId: 1, repository: repo),
          routes: {
            '/booking': (context) {
              capturedBookingDoctorId = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Màn hình Chọn ngày giờ đặt khám'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút Đặt lịch khám
      await tester.tap(find.text('Đặt lịch khám'));
      await tester.pumpAndSettle();

      expect(capturedBookingDoctorId, 1);
      expect(find.text('Màn hình Chọn ngày giờ đặt khám'), findsOneWidget);
    });
  });
}
