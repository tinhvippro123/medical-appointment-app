import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/main.dart';
import 'package:medical_appointment_app/models/doctor.dart';
import 'package:medical_appointment_app/models/doctor_day_off.dart';
import 'package:medical_appointment_app/repositories/doctor_day_off_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_schedule_repository.dart';
import 'package:medical_appointment_app/screens/admin/doctors/doctor_admin_page.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/doctor_schedule_logic.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/doctor_schedule_page.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/day_off_form_sheet.dart';
import 'package:medical_appointment_app/screens/admin/doctors/schedule/widgets/schedule_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleScheduleJson({
  int id = 1,
  int doctorId = 1,
  int dayOfWeek = 1,
  String startTime = '07:00:00',
  String endTime = '11:30:00',
  int maxPatients = 20,
}) => {
  'id': id,
  'doctorId': doctorId,
  'dayOfWeek': dayOfWeek,
  'startTime': startTime,
  'endTime': endTime,
  'maxPatients': maxPatients,
};

Map<String, dynamic> sampleDayOffJson({
  int id = 1,
  int doctorId = 1,
  String date = '2026-11-28',
  String? reason = 'Nghỉ phép',
}) => {
  'id': id,
  'doctorId': doctorId,
  'date': date,
  'reason': reason,
  'createdAt': '2026-11-25T08:00:00',
  'updatedAt': null,
};

http.Response jsonResponse(Object? body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'admin_jwt_token'});
  });

  group('1. Parse Model & Gom hiển thị theo thứ', () {
    test('DoctorSchedule parse đầy đủ trường, dayName và toRequestJson', () {
      final schedule = DoctorSchedule.fromJson(
        sampleScheduleJson(
          id: 12,
          doctorId: 5,
          dayOfWeek: 0,
          startTime: '08:00:00',
          endTime: '11:30:00',
          maxPatients: 15,
        ),
      );

      expect(schedule.id, 12);
      expect(schedule.doctorId, 5);
      expect(schedule.dayOfWeek, 0);
      expect(schedule.dayName, 'Chủ nhật');
      expect(schedule.startTimeFormatted, '08:00');
      expect(schedule.endTimeFormatted, '11:30');
      expect(schedule.timeRangeDisplay, '08:00-11:30');
      expect(schedule.maxPatients, 15);
      expect(schedule.toRequestJson(), {
        'dayOfWeek': 0,
        'startTime': '08:00:00',
        'endTime': '11:30:00',
        'maxPatients': 15,
      });

      expect(DoctorSchedule.dayOfWeekLabel(0), 'Chủ nhật');
      expect(DoctorSchedule.dayOfWeekLabel(1), 'Thứ 2');
      expect(DoctorSchedule.dayOfWeekLabel(6), 'Thứ 7');
      expect(DoctorSchedule.formatApiTime('7:5'), '07:05:00');
    });

    test('DoctorDayOff parse DateOnly yyyy-MM-dd và định dạng hiển thị', () {
      final dayOff = DoctorDayOff.fromJson(
        sampleDayOffJson(
          id: 7,
          doctorId: 3,
          date: '2026-11-30',
          reason: 'Hội thảo y khoa',
        ),
      );

      expect(dayOff.id, 7);
      expect(dayOff.doctorId, 3);
      expect(dayOff.dateOnly, DateTime(2026, 11, 30));
      expect(dayOff.dateApiString, '2026-11-30');
      expect(dayOff.dateDisplay, '30/11/2026');
      expect(dayOff.dayOfWeekLabel, 'Thứ 2');
      expect(dayOff.reason, 'Hội thảo y khoa');
    });

    test('GroupedDoctorSchedule gom nhiều ca và sắp xếp Thứ 2 -> Chủ nhật', () {
      const schedules = [
        DoctorSchedule(
          id: 1,
          dayOfWeek: 0,
          startTime: '08:00:00',
          endTime: '11:00:00',
          maxPatients: 10,
        ),
        DoctorSchedule(
          id: 2,
          dayOfWeek: 1,
          startTime: '13:00:00',
          endTime: '17:00:00',
          maxPatients: 20,
        ),
        DoctorSchedule(
          id: 3,
          dayOfWeek: 1,
          startTime: '07:00:00',
          endTime: '11:30:00',
          maxPatients: 20,
        ),
        DoctorSchedule(
          id: 4,
          dayOfWeek: 3,
          startTime: '13:00:00',
          endTime: '17:00:00',
          maxPatients: 15,
        ),
      ];

      final grouped = GroupedDoctorSchedule.groupAndSort(schedules);

      expect(grouped.length, 3);
      expect(grouped[0].dayName, 'Thứ 2');
      expect(grouped[0].timeSlotsDisplay, '07:00-11:30, 13:00-17:00');
      expect(grouped[0].fullDisplay, 'Thứ 2: 07:00-11:30, 13:00-17:00');
      expect(grouped[1].dayName, 'Thứ 4');
      expect(grouped[1].fullDisplay, 'Thứ 4: 13:00-17:00');
      expect(grouped[2].dayName, 'Chủ nhật');
      expect(grouped[2].fullDisplay, 'Chủ nhật: 08:00-11:00');
    });
  });

  group('2. Pure Validation Logic Unit Tests', () {
    test('Validate lịch làm việc: thứ, giờ bắt đầu < kết thúc, maxPatients > 0', () {
      expect(validateScheduleDayOfWeek(null), 'Vui lòng chọn thứ trong tuần');
      expect(validateScheduleDayOfWeek(7), 'Vui lòng chọn thứ trong tuần');
      expect(validateScheduleDayOfWeek(0), isNull);

      expect(validateScheduleStartTime(null), 'Vui lòng chọn giờ bắt đầu');
      expect(
        validateScheduleEndTime(const TimeOfDay(hour: 7, minute: 0), null),
        'Vui lòng chọn giờ kết thúc',
      );
      expect(
        validateScheduleEndTime(
          const TimeOfDay(hour: 11, minute: 30),
          const TimeOfDay(hour: 11, minute: 30),
        ),
        'Giờ bắt đầu phải nhỏ hơn giờ kết thúc',
      );
      expect(
        validateScheduleEndTime(
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 13, minute: 0),
        ),
        'Giờ bắt đầu phải nhỏ hơn giờ kết thúc',
      );
      expect(
        validateScheduleEndTime(
          const TimeOfDay(hour: 7, minute: 0),
          const TimeOfDay(hour: 11, minute: 30),
        ),
        isNull,
      );

      expect(validateMaxPatients(''), 'Vui lòng nhập số bệnh nhân tối đa');
      expect(validateMaxPatients('0'), 'Số bệnh nhân tối đa phải lớn hơn 0');
      expect(validateMaxPatients('-5'), 'Số bệnh nhân tối đa phải lớn hơn 0');
      expect(validateMaxPatients('abc'), 'Số bệnh nhân tối đa phải lớn hơn 0');
      expect(validateMaxPatients('20'), isNull);
    });

    test('Validate ngày nghỉ theo UTC+7: hôm nay được, quá khứ bị chặn', () {
      // 2026-11-25 18:00 UTC = 2026-11-26 01:00 tại Việt Nam
      final utcNow = DateTime.utc(2026, 11, 25, 18, 0);
      expect(vietnamToday(utcNow), DateTime(2026, 11, 26));

      expect(
        validateDayOffDate(DateTime(2026, 11, 25), now: utcNow),
        'Không thể đăng ký ngày nghỉ trong quá khứ',
      );
      expect(
        validateDayOffDate(DateTime(2026, 11, 26), now: utcNow),
        isNull,
      );
      expect(
        validateDayOffDate(DateTime(2026, 11, 27), now: utcNow),
        isNull,
      );
      expect(
        validateDayOffReason('a' * 201),
        'Lý do không được vượt quá 200 ký tự',
      );
      expect(validateDayOffReason('Nghỉ phép'), isNull);
    });
  });

  group('3. DoctorScheduleRepository & DoctorDayOffRepository Tests', () {
    test('DoctorScheduleRepository CRUD thành công (GET, POST, PUT, DELETE)', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);

        if (request.method == 'GET' &&
            request.url.path == '/api/doctors/1/schedules') {
          return jsonResponse([
            sampleScheduleJson(id: 10, doctorId: 1, dayOfWeek: 1),
          ]);
        }

        if (request.method == 'POST' &&
            request.url.path == '/api/doctors/1/schedules') {
          return jsonResponse(
            sampleScheduleJson(
              id: 11,
              doctorId: 1,
              dayOfWeek: 3,
              startTime: '13:00:00',
              endTime: '17:00:00',
              maxPatients: 25,
            ),
            statusCode: 201,
          );
        }

        if (request.method == 'PUT' && request.url.path == '/api/schedules/11') {
          return jsonResponse(
            sampleScheduleJson(
              id: 11,
              doctorId: 1,
              dayOfWeek: 3,
              startTime: '13:30:00',
              endTime: '17:30:00',
              maxPatients: 30,
            ),
          );
        }

        if (request.method == 'DELETE' &&
            request.url.path == '/api/schedules/11') {
          return http.Response.bytes(const [], 204);
        }

        return jsonResponse({'message': 'Not Found'}, statusCode: 404);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'admin_token',
      );
      final repo = DoctorScheduleRepository(apiClient: apiClient);

      final list = await repo.getSchedules(1);
      expect(list.length, 1);
      expect(list.first.id, 10);

      final created = await repo.createSchedule(
        1,
        const DoctorScheduleFormInput(
          dayOfWeek: 3,
          startTime: '13:00:00',
          endTime: '17:00:00',
          maxPatients: 25,
        ),
      );
      expect(created.id, 11);
      expect(requests.last.headers['Authorization'], 'Bearer admin_token');
      expect(jsonDecode(requests.last.body), {
        'dayOfWeek': 3,
        'startTime': '13:00:00',
        'endTime': '17:00:00',
        'maxPatients': 25,
      });

      final updated = await repo.updateSchedule(
        11,
        const DoctorScheduleFormInput(
          dayOfWeek: 3,
          startTime: '13:30:00',
          endTime: '17:30:00',
          maxPatients: 30,
        ),
      );
      expect(updated.startTimeFormatted, '13:30');
      expect(updated.maxPatients, 30);
      expect(requests.last.url.path, '/api/schedules/11');

      await repo.deleteSchedule(11);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, '/api/schedules/11');
    });

    test('DoctorScheduleRepository ném ApiException khi trùng lịch hoặc lỗi 404', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return jsonResponse(
            {
              'statusCode': 400,
              'errorCode': 'DOCTOR_SCHEDULE_CONFLICT',
              'message': 'Bác sĩ đã có lịch trong khung giờ này!',
            },
            statusCode: 400,
          );
        }
        return jsonResponse(
          {
            'statusCode': 404,
            'errorCode': 'RESOURCE_NOT_FOUND',
            'message': 'Không tìm thấy tài nguyên yêu cầu!',
          },
          statusCode: 404,
        );
      });

      final repo = DoctorScheduleRepository(
        apiClient: ApiClient(client: mockClient, baseUrl: 'http://test.api'),
      );

      expect(
        () => repo.createSchedule(
          1,
          const DoctorScheduleFormInput(
            dayOfWeek: 1,
            startTime: '07:00:00',
            endTime: '11:00:00',
            maxPatients: 20,
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.errorCode, 'errorCode', 'DOCTOR_SCHEDULE_CONFLICT')
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'Bác sĩ đã có lịch trong khung giờ này!',
              ),
        ),
      );

      expect(
        () => repo.deleteSchedule(999),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'RESOURCE_NOT_FOUND',
          ),
        ),
      );
    });

    test('DoctorDayOffRepository GET/POST/DELETE thành công và xử lý lỗi backend', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);

        if (request.method == 'GET' &&
            request.url.path == '/api/doctors/2/day-offs') {
          return jsonResponse([
            sampleDayOffJson(id: 5, doctorId: 2, date: '2026-11-28'),
          ]);
        }

        if (request.method == 'POST' &&
            request.url.path == '/api/doctors/2/day-offs') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['date'] == '2026-12-01') {
            return jsonResponse(
              {
                'statusCode': 400,
                'errorCode': 'DOCTOR_DAY_OFF_HAS_ORDERS',
                'message':
                    'Bác sĩ đã có 3 đơn đặt lịch vào ngày này, không thể đăng ký ngày nghỉ!',
              },
              statusCode: 400,
            );
          }
          if (body['date'] == '2026-11-28') {
            return jsonResponse(
              {
                'statusCode': 400,
                'errorCode': 'DAY_OFF_ALREADY_EXISTS',
                'message': 'Bác sĩ đã đăng ký nghỉ vào ngày này!',
              },
              statusCode: 400,
            );
          }
          return jsonResponse(
            sampleDayOffJson(
              id: 8,
              doctorId: 2,
              date: body['date'] as String,
              reason: body['reason'] as String?,
            ),
            statusCode: 201,
          );
        }

        if (request.method == 'DELETE' &&
            request.url.path == '/api/doctors/2/day-offs/8') {
          return http.Response.bytes(const [], 204);
        }

        return jsonResponse(
          {
            'statusCode': 404,
            'errorCode': 'DAY_OFF_NOT_FOUND',
            'message': 'Không tìm thấy ngày nghỉ của bác sĩ!',
          },
          statusCode: 404,
        );
      });

      final repo = DoctorDayOffRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_token',
        ),
      );

      final list = await repo.getDayOffs(
        2,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      expect(list.length, 1);
      expect(requests.last.url.queryParameters, {
        'from': '2026-11-01',
        'to': '2026-11-30',
      });

      final created = await repo.createDayOff(
        2,
        DoctorDayOffFormInput(
          date: DateTime(2026, 11, 29),
          reason: 'Đi công tác',
        ),
      );
      expect(created.id, 8);
      expect(created.reason, 'Đi công tác');

      await repo.deleteDayOff(2, 8);
      expect(requests.last.method, 'DELETE');

      await expectLater(
        repo.createDayOff(
          2,
          DoctorDayOffFormInput(date: DateTime(2026, 12, 1)),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.errorCode, 'errorCode', 'DOCTOR_DAY_OFF_HAS_ORDERS')
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'Bác sĩ đã có 3 đơn đặt lịch vào ngày này, không thể đăng ký ngày nghỉ!',
              ),
        ),
      );

      await expectLater(
        repo.createDayOff(
          2,
          DoctorDayOffFormInput(date: DateTime(2026, 11, 28)),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'DAY_OFF_ALREADY_EXISTS',
          ),
        ),
      );

      await expectLater(
        repo.deleteDayOff(2, 999),
        throwsA(
          isA<ApiException>().having(
            (e) => e.errorCode,
            'errorCode',
            'DAY_OFF_NOT_FOUND',
          ),
        ),
      );
    });
  });

  group('4. DoctorSchedulePage 4 Trạng thái cho cả 2 phần', () {
    testWidgets('Phần Lịch làm việc: Loading -> Lỗi + Thử lại -> Rỗng -> Dữ liệu gom theo thứ', (
      tester,
    ) async {
      final loadingCompleter = Completer<http.Response>();
      var scheduleAttempt = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/doctors/1/schedules') {
          scheduleAttempt++;
          if (scheduleAttempt == 1) {
            return loadingCompleter.future;
          }
          if (scheduleAttempt == 2) {
            return jsonResponse(
              {
                'statusCode': 500,
                'errorCode': 'INTERNAL_SERVER_ERROR',
                'message': 'Lỗi tải lịch làm việc',
              },
              statusCode: 500,
            );
          }
          if (scheduleAttempt == 3) {
            return jsonResponse([]);
          }
          return jsonResponse([
            sampleScheduleJson(
              id: 1,
              dayOfWeek: 3,
              startTime: '13:00:00',
              endTime: '17:00:00',
              maxPatients: 15,
            ),
            sampleScheduleJson(
              id: 2,
              dayOfWeek: 1,
              startTime: '07:00:00',
              endTime: '11:30:00',
              maxPatients: 20,
            ),
          ]);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorSchedulePage(
            doctorId: 1,
            doctorName: 'BS Nguyễn Văn A',
            scheduleRepository: DoctorScheduleRepository(apiClient: apiClient),
            dayOffRepository: DoctorDayOffRepository(apiClient: apiClient),
            now: DateTime(2026, 11, 25),
          ),
        ),
      );

      // 1. Trạng thái Loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Giải phóng lần 1 -> sang lần 2? Không, lần 1 trả về lỗi!
      loadingCompleter.complete(
        jsonResponse(
          {'statusCode': 500, 'message': 'Lỗi kết nối lịch làm việc'},
          statusCode: 500,
        ),
      );
      await tester.pumpAndSettle();

      // 2. Trạng thái Lỗi + Thử lại
      expect(find.text('Lỗi kết nối lịch làm việc'), findsOneWidget);
      expect(find.byKey(const ValueKey('schedules-retry-button')), findsOneWidget);

      // Nhấn Thử lại -> lần 2 trả lỗi -> nhấn Thử lại lần nữa -> lần 3 trả rỗng
      await tester.tap(find.byKey(const ValueKey('schedules-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Lỗi tải lịch làm việc'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('schedules-retry-button')));
      await tester.pumpAndSettle();

      // 3. Trạng thái Rỗng
      expect(find.text('Chưa có lịch làm việc'), findsOneWidget);

      // Tải lại lần 4 -> Có dữ liệu gom theo thứ
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();

      // 4. Trạng thái Dữ liệu
      expect(find.text('BS Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Thứ 2: 07:00-11:30'), findsOneWidget);
      expect(find.text('Thứ 4: 13:00-17:00'), findsOneWidget);
      expect(find.text('Tối đa 20 bệnh nhân'), findsOneWidget);
      expect(find.text('Tối đa 15 bệnh nhân'), findsOneWidget);
    });

    testWidgets('Phần Ngày nghỉ: Loading -> Lỗi + Thử lại -> Rỗng -> Dữ liệu', (
      tester,
    ) async {
      final dayOffCompleter = Completer<http.Response>();
      var dayOffAttempt = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1/schedules') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          dayOffAttempt++;
          if (dayOffAttempt == 1) {
            return dayOffCompleter.future;
          }
          if (dayOffAttempt == 2) {
            return jsonResponse(
              {'statusCode': 500, 'message': 'Lỗi tải danh sách ngày nghỉ'},
              statusCode: 500,
            );
          }
          return jsonResponse([
            sampleDayOffJson(
              id: 5,
              doctorId: 1,
              date: '2026-11-25',
              reason: 'Nghỉ phép năm',
            ),
          ]);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorSchedulePage(
            doctorId: 1,
            doctorName: 'BS Nguyễn Văn A',
            scheduleRepository: DoctorScheduleRepository(apiClient: apiClient),
            dayOffRepository: DoctorDayOffRepository(apiClient: apiClient),
            now: DateTime(2026, 11, 25),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chuyển sang tab Ngày nghỉ khi request đang chờ Completer
      await tester.tap(find.byKey(const ValueKey('day-offs-tab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // 1. Trạng thái Loading của tab Ngày nghỉ
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 2. Giải phóng -> Rỗng
      dayOffCompleter.complete(jsonResponse([]));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ngày nghỉ nào'), findsOneWidget);

      // 3. Tải lại -> Lỗi + Thử lại
      await tester.tap(find.text('Tải lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lỗi tải danh sách ngày nghỉ'), findsOneWidget);
      expect(find.byKey(const ValueKey('day-offs-retry-button')), findsOneWidget);

      // 4. Bấm Thử lại -> Dữ liệu
      await tester.tap(find.byKey(const ValueKey('day-offs-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Thứ 4, 25/11/2026'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Nghỉ phép năm'), findsOneWidget);
    });
  });

  group('5. CRUD, Validate Form, Chống bấm đúp, Lỗi Backend & Confirm Xóa', () {
    testWidgets('Thêm mới, sửa lịch và xác nhận xóa lịch làm việc trên DoctorSchedulePage', (
      tester,
    ) async {
      final schedules = <Map<String, dynamic>>[
        sampleScheduleJson(
          id: 10,
          doctorId: 1,
          dayOfWeek: 1,
          startTime: '07:00:00',
          endTime: '11:30:00',
          maxPatients: 20,
        ),
      ];
      var deleteCalls = 0;
      Map<String, dynamic>? lastPostBody;
      Map<String, dynamic>? lastPutBody;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/doctors/1/schedules') {
          return jsonResponse(schedules);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/doctors/1/schedules') {
          lastPostBody = jsonDecode(request.body) as Map<String, dynamic>;
          final newItem = sampleScheduleJson(
            id: 11,
            doctorId: 1,
            dayOfWeek: lastPostBody!['dayOfWeek'] as int,
            startTime: lastPostBody!['startTime'] as String,
            endTime: lastPostBody!['endTime'] as String,
            maxPatients: lastPostBody!['maxPatients'] as int,
          );
          schedules.add(newItem);
          return jsonResponse(newItem, statusCode: 201);
        }
        if (request.method == 'PUT' && request.url.path == '/api/schedules/10') {
          lastPutBody = jsonDecode(request.body) as Map<String, dynamic>;
          schedules[0] = sampleScheduleJson(
            id: 10,
            doctorId: 1,
            dayOfWeek: lastPutBody!['dayOfWeek'] as int,
            startTime: lastPutBody!['startTime'] as String,
            endTime: lastPutBody!['endTime'] as String,
            maxPatients: lastPutBody!['maxPatients'] as int,
          );
          return jsonResponse(schedules[0]);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/schedules/11') {
          deleteCalls++;
          schedules.removeWhere((e) => e['id'] == 11);
          return http.Response.bytes(const [], 204);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorSchedulePage(
            doctorId: 1,
            doctorName: 'BS Trần B',
            scheduleRepository: DoctorScheduleRepository(apiClient: apiClient),
            dayOffRepository: DoctorDayOffRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Thêm lịch mới qua FAB + TimeOfDay picker thật
      await tester.tap(find.byKey(const ValueKey('add-schedule-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('schedule-day-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thứ 4').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('schedule-start-time-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('schedule-end-time-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('schedule-max-patients-field')),
        '25',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pumpAndSettle();

      expect(lastPostBody, {
        'dayOfWeek': 3,
        'startTime': '07:00:00',
        'endTime': '11:30:00',
        'maxPatients': 25,
      });
      expect(find.text('Thêm lịch làm việc thành công.'), findsOneWidget);
      expect(find.text('Thứ 4: 07:00-11:30'), findsOneWidget);

      // 2. Bấm vào lịch hiện có -> mở cùng form để sửa
      await tester.ensureVisible(find.byKey(const ValueKey('schedule-item-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-item-10')));
      await tester.pumpAndSettle();

      expect(find.text('Sửa lịch làm việc'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-max-patients-field')),
        '30',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pumpAndSettle();

      expect(lastPutBody?['maxPatients'], 30);
      expect(find.text('Tối đa 30 bệnh nhân'), findsOneWidget);

      // 3. Xóa lịch: Hủy không xóa -> Xác nhận xóa và tải lại
      await tester.ensureVisible(
        find.byKey(const ValueKey('delete-schedule-11')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-schedule-11')));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);

      await tester.ensureVisible(
        find.byKey(const ValueKey('delete-schedule-11')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-schedule-11')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(deleteCalls, 1);
      expect(find.text('Thứ 4: 07:00-11:30'), findsNothing);

      // 4. Swipe để xóa lịch còn lại (id: 10) -> hiện confirm dialog
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-dismiss-10')),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('schedule-dismiss-10')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-item-10')), findsOneWidget);
    });

    testWidgets('ScheduleFormSheet: validate form, chống bấm đúp và lỗi trùng lịch', (
      tester,
    ) async {
      final postCompleter = Completer<http.Response>();
      var postCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          postCount++;
          return postCompleter.future;
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = DoctorScheduleRepository(
        apiClient: ApiClient(client: mockClient, baseUrl: 'http://test.api'),
      );

      var pickIndex = 0;
      Future<TimeOfDay?> customTimePicker(
        BuildContext context,
        TimeOfDay initial,
      ) async {
        pickIndex++;
        if (pickIndex == 1) return const TimeOfDay(hour: 15, minute: 0);
        if (pickIndex == 2) return const TimeOfDay(hour: 10, minute: 0);
        if (pickIndex == 3) return const TimeOfDay(hour: 8, minute: 0);
        return const TimeOfDay(hour: 11, minute: 0);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ScheduleFormSheet(
              doctorId: 1,
              scheduleRepository: repo,
              timePicker: customTimePicker,
            ),
          ),
        ),
      );

      // Submit khi chưa chọn thứ/giờ -> hiện lỗi validate
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng chọn thứ trong tuần'), findsOneWidget);
      expect(find.text('Vui lòng chọn giờ bắt đầu'), findsOneWidget);
      expect(find.text('Vui lòng chọn giờ kết thúc'), findsOneWidget);

      // Chọn thứ + start >= end + maxPatients = 0
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-day-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-day-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thứ 2').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-start-time-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-start-time-field')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-end-time-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-end-time-field')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-max-patients-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-max-patients-field')),
        '0',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Giờ bắt đầu phải nhỏ hơn giờ kết thúc'),
        findsOneWidget,
      );
      expect(
        find.text('Số bệnh nhân tối đa phải lớn hơn 0'),
        findsOneWidget,
      );
      expect(postCount, 0);

      // Nhập hợp lệ -> test chống bấm đúp và lỗi backend
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-start-time-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-start-time-field')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-end-time-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-end-time-field')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-max-patients-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('schedule-max-patients-field')),
        '20',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pump();

      final disabledSubmitBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('submit-schedule-button')),
      );
      expect(disabledSubmitBtn.onPressed, isNull);

      // Bấm lần 2 trong lúc đang gửi
      await tester.tap(find.byKey(const ValueKey('submit-schedule-button')));
      await tester.pump();

      expect(postCount, 1);

      postCompleter.complete(
        jsonResponse(
          {
            'statusCode': 400,
            'errorCode': 'DOCTOR_SCHEDULE_CONFLICT',
            'message': 'Bác sĩ đã có lịch trong khung giờ này!',
          },
          statusCode: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('schedule-form-error')), findsOneWidget);
      expect(
        find.text('Bác sĩ đã có lịch trong khung giờ này!'),
        findsOneWidget,
      );
    });

    testWidgets('Thêm ngày nghỉ với DatePicker (từ hôm nay), lỗi có đơn và confirm xóa ngày nghỉ', (
      tester,
    ) async {
      final dayOffs = <Map<String, dynamic>>[];
      var failWithOrders = true;
      var deleteCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1/schedules') {
          return jsonResponse([]);
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse(dayOffs);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/doctors/1/day-offs') {
          if (failWithOrders) {
            return jsonResponse(
              {
                'statusCode': 400,
                'errorCode': 'DOCTOR_DAY_OFF_HAS_ORDERS',
                'message':
                    'Bác sĩ đã có 2 đơn đặt lịch vào ngày này, không thể đăng ký ngày nghỉ!',
              },
              statusCode: 400,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final item = sampleDayOffJson(
            id: 21,
            doctorId: 1,
            date: body['date'] as String,
            reason: body['reason'] as String?,
          );
          dayOffs.add(item);
          return jsonResponse(item, statusCode: 201);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/doctors/1/day-offs/21') {
          deleteCalls++;
          dayOffs.removeWhere((e) => e['id'] == 21);
          return http.Response.bytes(const [], 204);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorSchedulePage(
            doctorId: 1,
            doctorName: 'BS Lê C',
            scheduleRepository: DoctorScheduleRepository(apiClient: apiClient),
            dayOffRepository: DoctorDayOffRepository(apiClient: apiClient),
            now: DateTime(2026, 11, 25, 9, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chuyển sang tab Ngày nghỉ và mở form thêm
      await tester.tap(find.byKey(const ValueKey('day-offs-tab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-day-off-fab')));
      await tester.pumpAndSettle();

      // Chọn ngày bằng DatePicker thật (mặc định mở ở hôm nay 25/11/2026)
      await tester.tap(find.byKey(const ValueKey('day-off-date-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('day-off-reason-field')),
        'Nghỉ phép',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pumpAndSettle();

      // Hiển thị đúng message backend khi ngày đã có đơn
      expect(find.byKey(const ValueKey('day-off-form-error')), findsOneWidget);
      expect(
        find.text(
          'Bác sĩ đã có 2 đơn đặt lịch vào ngày này, không thể đăng ký ngày nghỉ!',
        ),
        findsOneWidget,
      );

      // Gửi lại thành công -> đóng form và tải lại danh sách
      failWithOrders = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pumpAndSettle();

      expect(find.text('Thêm ngày nghỉ thành công.'), findsOneWidget);
      expect(find.text('Thứ 4, 25/11/2026'), findsOneWidget);
      expect(find.text('Nghỉ phép'), findsOneWidget);

      // Xác nhận xóa ngày nghỉ
      await tester.ensureVisible(find.byKey(const ValueKey('delete-day-off-21')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-day-off-21')));
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận xóa'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();

      expect(deleteCalls, 1);
      expect(find.text('Chưa có ngày nghỉ nào'), findsOneWidget);
    });

    testWidgets('DayOffFormSheet validate ngày nghỉ rỗng/quá khứ và chống bấm đúp', (
      tester,
    ) async {
      final postCompleter = Completer<http.Response>();
      var postCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          postCount++;
          return postCompleter.future;
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = DoctorDayOffRepository(
        apiClient: ApiClient(client: mockClient, baseUrl: 'http://test.api'),
      );

      var pickAttempt = 0;
      DateTime? capturedFirstDate;
      Future<DateTime?> customDatePicker(
        BuildContext context,
        DateTime initial,
        DateTime first,
        DateTime last,
      ) async {
        capturedFirstDate = first;
        pickAttempt++;
        if (pickAttempt == 1) {
          return DateTime(2026, 11, 24);
        }
        return DateTime(2026, 11, 25);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DayOffFormSheet(
              doctorId: 1,
              dayOffRepository: repo,
              now: DateTime(2026, 11, 25, 10, 0),
              datePicker: customDatePicker,
            ),
          ),
        ),
      );

      // Submit khi chưa chọn ngày -> báo lỗi
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn ngày nghỉ'), findsOneWidget);

      // Ngày quá khứ -> báo lỗi & firstDate phải từ hôm nay
      await tester.ensureVisible(
        find.byKey(const ValueKey('day-off-date-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-off-date-field')));
      await tester.pumpAndSettle();
      expect(capturedFirstDate, DateTime(2026, 11, 25));

      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Không thể đăng ký ngày nghỉ trong quá khứ'),
        findsOneWidget,
      );
      expect(postCount, 0);

      // Chọn hôm nay -> hợp lệ -> kiểm tra chống bấm đúp
      await tester.ensureVisible(
        find.byKey(const ValueKey('day-off-date-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-off-date-field')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pump();

      final disabledBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('submit-day-off-button')),
      );
      expect(disabledBtn.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('submit-day-off-button')));
      await tester.pump();

      expect(postCount, 1);

      postCompleter.complete(
        jsonResponse(
          {
            'statusCode': 400,
            'errorCode': 'DAY_OFF_ALREADY_EXISTS',
            'message': 'Bác sĩ đã đăng ký nghỉ vào ngày này!',
          },
          statusCode: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bác sĩ đã đăng ký nghỉ vào ngày này!'),
        findsOneWidget,
      );
    });
  });

  group('6. Điều hướng từ DoctorAdminPage & Route /admin/doctors/schedules', () {
    testWidgets('Nút "Lịch làm việc" trên DoctorAdminCard mở DoctorSchedulePage', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors') {
          return jsonResponse({
            'items': [
              {
                'id': 9,
                'fullName': 'BS Phạm Thị D',
                'qualification': 'CKI',
                'departmentId': 1,
                'departmentName': 'Khoa Nhi',
                'experienceYears': 6,
                'consultationFee': 180000,
                'isActive': true,
              },
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        }
        if (request.url.path == '/api/doctors/9/schedules') {
          return jsonResponse([
            sampleScheduleJson(
              id: 100,
              doctorId: 9,
              dayOfWeek: 2,
              startTime: '08:00:00',
              endTime: '11:30:00',
            ),
          ]);
        }
        if (request.url.path == '/api/doctors/9/day-offs') {
          return jsonResponse([]);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorAdminPage(
            doctorRepository: DoctorRepository(apiClient: apiClient),
            scheduleRepository: DoctorScheduleRepository(apiClient: apiClient),
            dayOffRepository: DoctorDayOffRepository(apiClient: apiClient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lịch làm việc'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-doctor-9')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('schedule-doctor-9')));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorSchedulePage), findsOneWidget);
      expect(find.text('Lịch làm việc & Ngày nghỉ'), findsOneWidget);
      expect(find.text('BS Phạm Thị D'), findsOneWidget);
      expect(find.text('Thứ 3: 08:00-11:30'), findsOneWidget);
    });

    testWidgets('Route /admin/doctors/schedules nhận doctorId + tên bác sĩ', (
      tester,
    ) async {
      await tester.pumpWidget(
        MyApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/admin/doctors/schedules',
                      arguments: const DoctorScheduleRouteArgs(
                        doctorId: 15,
                        doctorName: 'BS Route Test',
                      ),
                    );
                  },
                  child: const Text('Mở lịch'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở lịch'));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorSchedulePage), findsOneWidget);
      expect(find.text('Lịch làm việc & Ngày nghỉ'), findsOneWidget);
      expect(find.text('BS Route Test'), findsOneWidget);
    });
  });
}
