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
import 'package:medical_appointment_app/models/doctor_day_off.dart';
import 'package:medical_appointment_app/models/patient_profile.dart';
import 'package:medical_appointment_app/repositories/cart_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/repositories/patient_profile_repository.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'package:medical_appointment_app/screens/booking/booking_logic.dart';
import 'package:medical_appointment_app/screens/booking/booking_page.dart';
import 'package:medical_appointment_app/screens/booking/booking_review_page.dart';
import 'package:medical_appointment_app/screens/doctors/detail/doctor_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleBookingDoctorJson({
  int id = 1,
  String fullName = 'Nguyễn Minh Anh',
  String? qualification = 'ThS.BS',
  List<Map<String, dynamic>>? schedules,
}) => {
  'id': id,
  'fullName': fullName,
  'qualification': qualification,
  'email': 'bs.anh@example.com',
  'phone': '0901002003',
  'departmentId': 1,
  'departmentName': 'Nội tổng quát',
  'roomId': 10,
  'roomNumber': '101',
  'floor': 1,
  'description': 'Bác sĩ chuyên khoa nội',
  'avatarUrl': null,
  'experienceYears': 10,
  'consultationFee': 150000,
  'isActive': true,
  'schedules': schedules ??
      [
        {
          'id': 11,
          'dayOfWeek': 3, // Thứ 4 (25/11/2026)
          'startTime': '08:00:00',
          'endTime': '11:30:00',
          'maxPatients': 20,
        },
        {
          'id': 12,
          'dayOfWeek': 5, // Thứ 6 (27/11/2026)
          'startTime': '13:30:00',
          'endTime': '16:00:00',
          'maxPatients': 20,
        },
      ],
};

List<Map<String, dynamic>> sampleProfilesJson() => [
  {
    'id': 101,
    'fullName': 'Trần Văn An',
    'dateOfBirth': '1995-05-12T00:00:00',
    'gender': 'Nam',
    'relationship': 'Bản thân',
  },
  {
    'id': 102,
    'fullName': 'Trần Bé Bình',
    'dateOfBirth': '2020-08-20T00:00:00',
    'gender': 'Nam',
    'relationship': 'Con',
  },
];

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
    SharedPreferences.setMockInitialValues({'jwt_token': 'valid_jwt_token'});
  });

  for (final width in [320.0, 1440.0]) {
    testWidgets('Xác nhận thông tin dễ đọc ở chiều rộng $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(width < 760 ? 1.5 : 1),
            ),
            child: child!,
          ),
          home: BookingReviewPage(
            doctor: Doctor.fromJson(sampleBookingDoctorJson()),
            patient: const PatientProfile(
              id: 101,
              fullName: 'Trần Thị Minh Phương Anh',
              relationship: 'Bản thân',
            ),
            date: DateTime(2026, 11, 27),
            slot: '09:00-10:00',
            note: 'Mang theo kết quả khám gần nhất để bác sĩ xem lại.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final details = tester.getTopLeft(find.text('Thông tin lịch hẹn'));
      final payment = tester.getTopLeft(find.text('Phí khám'));
      if (width >= 760) {
        expect(payment.dy, closeTo(details.dy, 1));
        expect(payment.dx, greaterThan(details.dx));
      } else {
        expect(payment.dy, greaterThan(details.dy));
      }
      final button = find.ancestor(
        of: find.text('Tiếp tục thanh toán'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      await tester.ensureVisible(button);
      expect(tester.getSize(button).width, lessThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
    });
  }

  group('1. Pure Logic: Sinh slot theo giờ', () {
    test('1 ca làm việc có phần lẻ cuối (07:00-11:30) bỏ 11:00-11:30', () {
      final monday = DateTime(2026, 11, 30); // Thứ 2 -> dayOfWeek = 1
      final slots = generateHourlySlotsForDate(
        date: monday,
        now: DateTime(2026, 11, 25, 8, 0),
        schedules: const [
          DoctorSchedule(
            id: 1,
            dayOfWeek: 1,
            startTime: '07:00:00',
            endTime: '11:30:00',
          ),
        ],
      );

      expect(
        slots.map((s) => s.label).toList(),
        ['07:00-08:00', '08:00-09:00', '09:00-10:00', '10:00-11:00'],
      );
    });

    test('Nhiều ca cùng ngày (chưa sắp xếp, có trùng) được gộp và sắp xếp theo giờ', () {
      final wednesday = DateTime(2026, 12, 2); // Thứ 4 -> dayOfWeek = 3
      final slots = generateHourlySlotsForDate(
        date: wednesday,
        now: DateTime(2026, 11, 25, 8, 0),
        schedules: const [
          DoctorSchedule(
            id: 2,
            dayOfWeek: 3,
            startTime: '13:30:00',
            endTime: '16:00:00',
          ),
          DoctorSchedule(
            id: 1,
            dayOfWeek: 3,
            startTime: '07:00:00',
            endTime: '09:30:00',
          ),
          DoctorSchedule(
            id: 3,
            dayOfWeek: 3,
            startTime: '07:00:00',
            endTime: '08:00:00',
          ),
          // Khác thứ -> không đưa vào
          DoctorSchedule(
            id: 4,
            dayOfWeek: 5,
            startTime: '18:00:00',
            endTime: '20:00:00',
          ),
        ],
      );

      expect(
        slots.map((s) => s.label).toList(),
        ['07:00-08:00', '08:00-09:00', '13:30-14:30', '14:30-15:30'],
      );
    });

    test('Ngày hôm nay lọc bỏ các slot đã qua theo giờ Việt Nam (tham số now)', () {
      final today = DateTime(2026, 11, 25); // Thứ 4
      final slots = generateHourlySlotsForDate(
        date: today,
        now: DateTime(2026, 11, 25, 9, 0), // Đúng 09:00 -> 09:00-10:00 cũng đã bắt đầu/qua
        schedules: const [
          DoctorSchedule(
            id: 1,
            dayOfWeek: 3,
            startTime: '07:00:00',
            endTime: '12:00:00',
          ),
          DoctorSchedule(
            id: 2,
            dayOfWeek: 3,
            startTime: '13:30:00',
            endTime: '15:30:00',
          ),
        ],
      );

      expect(
        slots.map((s) => s.label).toList(),
        ['10:00-11:00', '11:00-12:00', '13:30-14:30', '14:30-15:30'],
      );
    });

    test('Tham số now dạng UTC được cộng +7 sang giờ Việt Nam chính xác', () {
      final today = DateTime(2026, 11, 25);
      // 02:30 UTC == 09:30 UTC+7 -> lọc bỏ 07:00, 08:00, 09:00
      final slots = generateHourlySlotsForDate(
        date: today,
        now: DateTime.utc(2026, 11, 25, 2, 30),
        schedules: const [
          DoctorSchedule(
            id: 1,
            dayOfWeek: 3,
            startTime: '07:00:00',
            endTime: '11:00:00',
          ),
        ],
      );

      expect(slots.map((s) => s.label).toList(), ['10:00-11:00']);
    });

    test('Ngày quá khứ trả về danh sách slot rỗng', () {
      final yesterday = DateTime(2026, 11, 24);
      final slots = generateHourlySlotsForDate(
        date: yesterday,
        now: DateTime(2026, 11, 25, 8, 0),
        schedules: const [
          DoctorSchedule(
            id: 1,
            dayOfWeek: 2,
            startTime: '08:00:00',
            endTime: '12:00:00',
          ),
        ],
      );

      expect(slots, isEmpty);
    });
  });

  group('2. Pure Logic: selectableDayPredicate & tìm ngày hợp lệ đầu tiên', () {
    final firstDate = DateTime(2026, 11, 25); // Thứ 4
    final lastDate = DateTime(2027, 1, 24);
    const schedules = [
      DoctorSchedule(id: 1, dayOfWeek: 3, startTime: '08:00:00', endTime: '11:30:00'),
      DoctorSchedule(id: 2, dayOfWeek: 0, startTime: '08:00:00', endTime: '11:00:00'),
    ];

    test('Cho phép chọn ngày khớp DayOfWeek (bao gồm Chủ nhật = 0) trong [firstDate, lastDate]', () {
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 25), // Thứ 4
          schedules: schedules,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isTrue,
      );
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 29), // Chủ nhật
          schedules: schedules,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isTrue,
      );
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 26), // Thứ 5 - không có lịch
          schedules: schedules,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isFalse,
      );
    });

    test('Chặn ngày quá khứ và ngày vượt quá lastDate', () {
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 18), // Thứ 4 tuần trước
          schedules: schedules,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isFalse,
      );
      expect(
        isBookingDaySelectable(
          day: DateTime(2027, 1, 27), // Thứ 4 sau lastDate
          schedules: schedules,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isFalse,
      );
    });

    test('Chặn ngày nghỉ của bác sĩ (dayOffDates)', () {
      final dayOffs = {DateTime(2026, 11, 25)};
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 25),
          schedules: schedules,
          dayOffDates: dayOffs,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isFalse,
      );
      expect(
        findFirstSelectableDate(
          schedules: schedules,
          dayOffDates: dayOffs,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        DateTime(2026, 11, 29), // Nhảy sang Chủ nhật hợp lệ kế tiếp
      );
    });

    test('Lịch rỗng trả false cho mọi ngày và findFirstSelectableDate trả null', () {
      expect(
        isBookingDaySelectable(
          day: DateTime(2026, 11, 25),
          schedules: const [],
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isFalse,
      );
      expect(
        findFirstSelectableDate(
          schedules: const [],
          firstDate: firstDate,
          lastDate: lastDate,
        ),
        isNull,
      );
    });
  });

  group('3. Models, CartRepository.addItem & Error Mapping', () {
    test('PatientProfile.fromJson và DoctorDayOff.fromJson parse an toàn null', () {
      final p = PatientProfile.fromJson({'id': 5, 'fullName': null, 'relationship': null});
      expect(p.id, 5);
      expect(p.fullName, '');
      expect(p.dateOfBirth, isNull);
      expect(p.displayLabel, 'Hồ sơ #5');

      final dayOff = DoctorDayOff.fromJson({
        'id': 1,
        'doctorId': 2,
        'date': '2026-11-27',
        'reason': null,
      });
      expect(dayOff.dateOnly, DateTime(2026, 11, 27));
    });

    test('CartRepository.addItem gửi đúng body POST /api/cart (ẩn note khi rỗng) và giữ errorCode', () async {
      final capturedBodies = <Map<String, dynamic>>[];

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/cart');
        expect(request.headers['Authorization'], 'Bearer jwt_test');

        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        capturedBodies.add(decoded);

        if (decoded['timeSlot'] == '09:00-10:00') {
          return jsonResponse(
            {
              'statusCode': 400,
              'errorCode': 'DOCTOR_NOT_FOUND',
              'message': 'Không tìm thấy thông tin bác sĩ!',
            },
            statusCode: 400,
          );
        }

        return jsonResponse(
          {
            'id': 99,
            'doctorId': decoded['doctorId'],
            'doctorFullName': 'Nguyễn Minh Anh',
            'doctorAvatarUrl': null,
            'doctorIsActive': true,
            'departmentName': 'Nội tổng quát',
            'consultationFee': 150000,
            'patientProfileId': decoded['patientProfileId'],
            'patientProfileFullName': 'Trần Văn An',
            'appointmentDate': decoded['appointmentDate'],
            'timeSlot': decoded['timeSlot'],
            'note': decoded['note'],
          },
          statusCode: 201,
        );
      });

      final repo = CartRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'jwt_test',
        ),
      );

      final created = await repo.addItem(
        doctorId: 1,
        patientProfileId: 101,
        appointmentDate: DateTime(2026, 11, 27),
        timeSlot: '13:30-14:30',
        note: '   ',
      );

      expect(created?.id, 99);
      expect(capturedBodies.first, {
        'doctorId': 1,
        'patientProfileId': 101,
        'appointmentDate': '2026-11-27',
        'timeSlot': '13:30-14:30',
      });
      expect(capturedBodies.first.containsKey('note'), isFalse);

      await expectLater(
        () => repo.addItem(
          doctorId: 1,
          patientProfileId: 101,
          appointmentDate: DateTime(2026, 11, 27),
          timeSlot: '09:00-10:00',
          note: 'Có ghi chú',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.errorCode, 'errorCode', 'DOCTOR_NOT_FOUND'),
        ),
      );
      expect(capturedBodies.last['note'], 'Có ghi chú');
    });

    test('mapBookingErrorMessage ánh xạ đúng mã lỗi và ValidationProblemDetails', () {
      expect(
        mapBookingErrorMessage(
          const ApiException(
            statusCode: 400,
            errorCode: 'DOCTOR_NOT_FOUND',
            message: 'raw',
          ),
        ),
        contains('bác sĩ'),
      );
      expect(
        mapBookingErrorMessage(
          const ApiException(
            statusCode: 400,
            errorCode: 'CART_ITEM_DUPLICATE',
            message: 'raw',
          ),
        ),
        'Lịch này đã có trong giỏ hàng',
      );
      expect(
        mapBookingErrorMessage(
          const ApiException(
            statusCode: 400,
            errorCode: 'DOCTOR_ON_LEAVE',
            message: 'raw',
          ),
        ),
        contains('nghỉ'),
      );
      expect(
        mapBookingErrorMessage(
          const ApiException(
            statusCode: 400,
            errorCode: 'APPOINTMENT_TIME_PASSED',
            message: 'raw',
          ),
        ),
        contains('trôi qua'),
      );
      expect(
        mapBookingErrorMessage(
          const ApiException(
            statusCode: 400,
            message: 'One or more validation errors occurred.',
            fieldErrors: {
              'AppointmentDate': ['Ngày khám không được ở trong quá khứ'],
              'TimeSlot': ['Định dạng không hợp lệ'],
            },
          ),
        ),
        'Ngày khám không được ở trong quá khứ',
      );
    });
  });

  group('4. BookingPage Widget Tests - 4 trạng thái, day-offs & hồ sơ', () {
    void configureScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('Hiển thị loading và không tìm thấy bác sĩ (404 DOCTOR_NOT_FOUND)', (tester) async {
      configureScreenSize(tester);

      final doctorCompleter = Completer<http.Response>();
      final mockClient404 = MockClient((request) async {
        if (request.url.path == '/api/doctors/99') {
          return doctorCompleter.future;
        }
        return jsonResponse([], statusCode: 200);
      });
      final api404 = ApiClient(
        client: mockClient404,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 99,
            doctorRepository: DoctorRepository(apiClient: api404),
            patientProfileRepository: PatientProfileRepository(apiClient: api404),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      doctorCompleter.complete(
        jsonResponse(
          {'errorCode': 'DOCTOR_NOT_FOUND', 'message': 'Không tìm thấy bác sĩ'},
          statusCode: 404,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy thông tin bác sĩ'), findsOneWidget);
    });

    testWidgets('Hiển thị lỗi khi tải bác sĩ (500) và bấm Thử lại thành công', (tester) async {
      configureScreenSize(tester);

      var attempts = 0;
      final mockRetry = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          attempts++;
          if (attempts == 1) {
            return jsonResponse(
              {
                'statusCode': 500,
                'errorCode': 'INTERNAL_SERVER_ERROR',
                'message': 'Đã xảy ra lỗi hệ thống nghiêm trọng!',
              },
              statusCode: 500,
            );
          }
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse({}, statusCode: 404);
      });
      final apiRetry = ApiClient(
        client: mockRetry,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: apiRetry),
            patientProfileRepository: PatientProfileRepository(apiClient: apiRetry),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Đã xảy ra lỗi hệ thống nghiêm trọng!'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.ensureVisible(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('ThS.BS Nguyễn Minh Anh'), findsOneWidget);
    });

    testWidgets('Lịch làm việc rỗng: hiện "Bác sĩ chưa có lịch làm việc" và khóa nút', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson(schedules: []));
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse([]);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bác sĩ chưa có lịch làm việc'), findsOneWidget);
      final submitBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('Hồ sơ rỗng: hiện thông báo và khóa nút xác nhận kể cả khi đã chọn slot', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse([]);
        }
        return jsonResponse({}, statusCode: 404);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn chưa có hồ sơ bệnh nhân. Hãy tạo hồ sơ trước khi đặt lịch.'),
        findsOneWidget,
      );

      // Chọn 1 slot
      await tester.ensureVisible(find.text('09:00-10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00-10:00'));
      await tester.pumpAndSettle();

      final submitBtn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-submit-button')),
      );
      expect(submitBtn.onPressed, isNull);
    });

    testWidgets('Lỗi tải day-offs chỉ hiện cảnh báo nhỏ, vẫn cho chọn ngày và slot', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse({'message': 'Day-offs lỗi'}, statusCode: 500);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse({}, statusCode: 404);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Không tải được ngày nghỉ của bác sĩ'),
        findsOneWidget,
      );
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.text('09:00-10:00'), findsOneWidget);
    });

    testWidgets('Ngày đầu tiên là ngày nghỉ -> tự động chọn ngày hợp lệ tiếp theo và vô hiệu ngày nghỉ', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          // 25/11/2026 là ngày nghỉ -> calendar tự chọn 27/11/2026 (Thứ 6)
          return jsonResponse([
            {
              'id': 1,
              'doctorId': 1,
              'date': '2026-11-25',
              'reason': 'Đi công tác',
            },
          ]);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse({}, statusCode: 404);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tự nhảy sang Thứ 6 (27/11/2026) -> hiện slot chiều 13:30-14:30
      expect(find.text('13:30-14:30'), findsOneWidget);

      // Bấm vào ngày nghỉ 25/11 không đổi được ngày
      final day25 = find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('25'),
      );
      await tester.ensureVisible(day25);
      await tester.pumpAndSettle();
      await tester.tap(day25);
      await tester.pumpAndSettle();

      expect(find.text('13:30-14:30'), findsOneWidget);
      expect(find.text('09:00-10:00'), findsNothing);
    });
  });

  group('5. BookingPage Widget Tests - Chọn ngày, slot, submit & lỗi', () {
    void configureScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets(
      'Chọn ngày -> hiện slot, chọn slot highlight, đổi ngày reset slot, nút disabled khi chưa chọn',
      (tester) async {
        configureScreenSize(tester);

        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/doctors/1') {
            return jsonResponse(sampleBookingDoctorJson());
          }
          if (request.url.path == '/api/doctors/1/day-offs') {
            return jsonResponse([]);
          }
          if (request.url.path == '/api/patient-profiles') {
            return jsonResponse(sampleProfilesJson());
          }
          return jsonResponse({}, statusCode: 404);
        });
        final api = ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'valid_jwt_token',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BookingPage(
              doctorId: 1,
              doctorRepository: DoctorRepository(apiClient: api),
              patientProfileRepository: PatientProfileRepository(apiClient: api),
              nowProvider: () => DateTime(2026, 11, 25, 8, 30),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nút disabled khi chưa chọn slot
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('booking-submit-button')),
              )
              .onPressed,
          isNull,
        );

        // Hôm nay 25/11 lúc 08:30: ẩn 08:00-09:00, hiện 09:00-10:00 và 10:00-11:00
        expect(find.text('08:00-09:00'), findsNothing);
        expect(find.text('09:00-10:00'), findsOneWidget);
        expect(find.text('10:00-11:00'), findsOneWidget);

        // Chọn ngày 27/11 (Thứ 6)
        final day27 = find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('27'),
        );
        await tester.ensureVisible(day27);
        await tester.pumpAndSettle();
        await tester.tap(day27);
        await tester.pumpAndSettle();

        expect(find.text('13:30-14:30'), findsOneWidget);
        expect(find.text('14:30-15:30'), findsOneWidget);
        expect(find.text('15:30-16:00'), findsNothing);

        // Chọn slot 13:30-14:30 -> highlight & bật nút
        final slotFinder = find.widgetWithText(ChoiceChip, '13:30-14:30');
        await tester.ensureVisible(slotFinder);
        await tester.pumpAndSettle();
        await tester.tap(slotFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<ChoiceChip>(slotFinder).selected, isTrue);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('booking-submit-button')),
              )
              .onPressed,
          isNotNull,
        );

        // Đổi sang ngày 25/11 -> reset slot đã chọn & khóa nút lại
        final day25 = find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('25'),
        );
        await tester.ensureVisible(day25);
        await tester.pumpAndSettle();
        await tester.tap(day25);
        await tester.pumpAndSettle();

        expect(find.text('09:00-10:00'), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '09:00-10:00'))
              .selected,
          isFalse,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('booking-submit-button')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets('Xác nhận giữ một lịch trong bộ nhớ và không gọi API giỏ', (
      tester,
    ) async {
      configureScreenSize(tester);
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          switch (request.url.path) {
            case '/api/doctors/1':
              return jsonResponse(sampleBookingDoctorJson());
            case '/api/doctors/1/day-offs':
              return jsonResponse([]);
            case '/api/patient-profiles':
              return jsonResponse(sampleProfilesJson());
            default:
              return jsonResponse({}, statusCode: 404);
          }
        }),
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookingPage(
                      doctorId: 1,
                      initialDate: DateTime(2026, 11, 27),
                      doctorRepository: DoctorRepository(apiClient: api),
                      patientProfileRepository:
                          PatientProfileRepository(apiClient: api),
                      nowProvider: () => DateTime(2026, 11, 25, 8, 30),
                    ),
                  ),
                ),
                child: const Text('Mở đặt lịch'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở đặt lịch'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.text('09:00-10:00'), findsNothing);
      final slot = find.widgetWithText(ChoiceChip, '13:30-14:30');
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();

      final note = find.byKey(const ValueKey('booking-note-field'));
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Khám tổng quát');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('booking-submit-button'));
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận thông tin'), findsOneWidget);
      expect(find.text('Trần Văn An (Bản thân)'), findsOneWidget);
      expect(find.text('Nội tổng quát'), findsOneWidget);
      expect(find.textContaining('13:30-14:30'), findsOneWidget);
      expect(find.text('Khám tổng quát'), findsOneWidget);
      expect(find.text('150.000 đ'), findsOneWidget);
      final payment = find.text('Tiếp tục thanh toán');
      final insurance = find.byType(CheckboxListTile);
      expect(tester.widget<CheckboxListTile>(insurance).value, isFalse);
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(find.text('Bảo hiểm y tế'), findsOneWidget);
      expect(find.text('Không'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(insurance);
      await tester.tap(insurance);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(insurance).value, isTrue);
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(find.text('Có'), findsOneWidget);
      expect(
        find.textContaining('Thanh toán trực tiếp tại quầy tiếp nhận'),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(slot).selected, isTrue);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(insurance).value, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở đặt lịch'));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(slot).selected, isFalse);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.ensureVisible(slot);
      await tester.tap(slot);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(insurance).value, isFalse);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(requests.where((request) => request.url.path == '/api/cart'), isEmpty);
    });

    testWidgets('Ngày chọn trước trùng ngày nghỉ không hiện khung giờ', (
      tester,
    ) async {
      final api = ApiClient(
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/api/doctors/1':
              return jsonResponse(sampleBookingDoctorJson());
            case '/api/doctors/1/day-offs':
              return jsonResponse([
                {'id': 1, 'doctorId': 1, 'date': '2026-11-27'},
              ]);
            default:
              return jsonResponse(sampleProfilesJson());
          }
        }),
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BookingPage(
            doctorId: 1,
            initialDate: DateTime(2026, 11, 27),
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bác sĩ nghỉ vào ngày đã chọn.'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      final button = find.byKey(const ValueKey('booking-submit-button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    testWidgets('Chưa đăng nhập khi xác nhận -> SnackBar + chuyển sang LoginPage', (tester) async {
      configureScreenSize(tester);
      SharedPreferences.setMockInitialValues({}); // Không có token

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        return jsonResponse({}, statusCode: 404);
      });

      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BookingPage(
            doctorId: 1,
            doctorRepository: DoctorRepository(apiClient: api),
            patientProfileRepository: PatientProfileRepository(apiClient: api),
            nowProvider: () => DateTime(2026, 11, 25, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slotFinder = find.widgetWithText(ChoiceChip, '09:00-10:00');
      await tester.ensureVisible(slotFinder);
      await tester.pumpAndSettle();
      await tester.tap(slotFinder);
      await tester.pumpAndSettle();

      final submitFinder = find.byKey(const ValueKey('booking-submit-button'));
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng đăng nhập để đặt lịch khám'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('DoctorDetailPage điều hướng sang /booking với doctorId không crash', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/related') {
          return jsonResponse({'items': [], 'totalCount': 0});
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse({}, statusCode: 404);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorDetailPage(
            doctorId: 1,
            repository: DoctorRepository(apiClient: api),
          ),
          routes: {
            '/booking': (context) {
              final arg = ModalRoute.of(context)?.settings.arguments;
              return BookingPage(
                doctorId: arg is int ? arg : int.tryParse(arg?.toString() ?? ''),
                doctorRepository: DoctorRepository(apiClient: api),
                patientProfileRepository:
                    PatientProfileRepository(apiClient: api),
                nowProvider: () => DateTime(2026, 11, 25, 8, 30),
              );
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      final bookBtn = find.text('Đặt lịch khám');
      await tester.ensureVisible(bookBtn);
      await tester.pumpAndSettle();
      await tester.tap(bookBtn);
      await tester.pumpAndSettle();

      expect(find.byType(BookingPage), findsOneWidget);
      expect(find.text('Đặt lịch · Nguyễn Minh Anh'), findsOneWidget);
    });

    testWidgets('Route /booking nhận arguments kiểu String và Doctor an toàn', (tester) async {
      configureScreenSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/doctors/1') {
          return jsonResponse(sampleBookingDoctorJson());
        }
        if (request.url.path == '/api/doctors/1/day-offs') {
          return jsonResponse([]);
        }
        if (request.url.path == '/api/patient-profiles') {
          return jsonResponse(sampleProfilesJson());
        }
        return jsonResponse({}, statusCode: 404);
      });
      final api = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'valid_jwt_token',
      );

      final sampleDoctor = Doctor.fromJson(sampleBookingDoctorJson(id: 1));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/booking', arguments: '1'),
                    child: const Text('Mở bằng String'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/booking',
                      arguments: sampleDoctor,
                    ),
                    child: const Text('Mở bằng Doctor'),
                  ),
                ],
              ),
            ),
          ),
          routes: {
            '/booking': (_) => BookingPage(
                  doctorRepository: DoctorRepository(apiClient: api),
                  patientProfileRepository:
                      PatientProfileRepository(apiClient: api),
                  nowProvider: () => DateTime(2026, 11, 25, 8, 30),
                ),
          },
        ),
      );

      await tester.tap(find.text('Mở bằng String'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lịch · Nguyễn Minh Anh'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở bằng Doctor'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lịch · Nguyễn Minh Anh'), findsOneWidget);
    });
  });
}
