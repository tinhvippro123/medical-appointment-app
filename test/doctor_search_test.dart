import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/screens/doctors/search/doctor_search_page.dart';
import 'package:medical_appointment_app/screens/doctors/search/widgets/doctor_search_card.dart';
import 'package:medical_appointment_app/screens/home/widgets/healthcare_functions_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sampleDoctorJson({
  int id = 1,
  String name = 'BS Nguyễn Văn A',
  String? qualification = 'ThS.BS',
  int departmentId = 1,
  String departmentName = 'Khoa Tim mạch',
  int? roomId = 10,
  String? roomNumber = '101',
  int? floor = 1,
  double fee = 150000,
  int experienceYears = 8,
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
  'experienceYears': experienceYears,
  'consultationFee': fee,
  'isActive': isActive,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DoctorRepository.searchDoctors Unit Tests', () {
    test('searchDoctors gửi đúng đường dẫn, query params và parse PagedResult', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);

        if (request.url.path == '/api/doctors/search') {
          final res = {
            'items': [
              sampleDoctorJson(id: 1, name: 'Nguyễn Văn A', qualification: 'ThS'),
              sampleDoctorJson(id: 2, name: 'Nguyễn Văn B', qualification: 'CKI'),
            ],
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
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'jwt_token',
      );
      final repo = DoctorRepository(apiClient: apiClient);

      final result = await repo.searchDoctors(
        keyword: 'Nguyễn',
        departmentId: 1,
        page: 1,
        pageSize: 10,
      );

      expect(requests.length, 1);
      final req = requests.first;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/doctors/search');
      expect(req.url.queryParameters['keyword'], 'Nguyễn');
      expect(req.url.queryParameters['departmentId'], '1');
      expect(req.url.queryParameters['page'], '1');
      expect(req.url.queryParameters['pageSize'], '10');

      expect(result.items.length, 2);
      expect(result.totalCount, 2);
      expect(result.page, 1);
      expect(result.pageSize, 10);
      expect(result.totalPages, 1);
      expect(result.hasPreviousPage, isFalse);
      expect(result.hasNextPage, isFalse);
      expect(result.items.first.fullName, 'Nguyễn Văn A');
    });

    test('searchDoctors khi keyword rỗng thì không truyền query keyword', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        final res = {
          'items': <dynamic>[],
          'totalCount': 0,
          'page': 1,
          'pageSize': 10,
          'totalPages': 0,
          'hasPreviousPage': false,
          'hasNextPage': false,
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(res)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'http://test.api',
      );
      final repo = DoctorRepository(apiClient: apiClient);

      await repo.searchDoctors(keyword: '   ');
      expect(requests.first.url.queryParameters.containsKey('keyword'), isFalse);
    });
  });

  group('DoctorSearchPage Widget Tests', () {
    testWidgets('DoctorSearchPage hiển thị CircularProgressIndicator khi đang tải dữ liệu', (tester) async {
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) => completer.future);
      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSearchPage(repository: repo),
        ),
      );
      await tester.pump(); // frame đầu tiên khi loading

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(http.Response.bytes(
        utf8.encode(jsonEncode({
          'items': [sampleDoctorJson(id: 1, name: 'BS Nguyễn Văn A')],
          'totalCount': 1,
          'page': 1,
          'pageSize': 10,
          'totalPages': 1,
          'hasPreviousPage': false,
          'hasNextPage': false,
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorSearchCard), findsOneWidget);
    });

    testWidgets('DoctorSearchPage hiển thị danh sách kết quả và bấm card chuyển sang chi tiết', (tester) async {
      dynamic capturedDoctorId;

      final mockClient = MockClient((request) async {
        final res = {
          'items': [
            sampleDoctorJson(
              id: 42,
              name: 'Nguyễn Văn Minh',
              qualification: 'ThS.BS',
              departmentName: 'Khoa Ngoại',
              fee: 180000,
              experienceYears: 12,
            ),
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
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSearchPage(repository: repo),
          routes: {
            '/doctors/detail': (context) {
              capturedDoctorId = ModalRoute.of(context)?.settings.arguments;
              return const Scaffold(body: Text('Chi tiết bác sĩ'));
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra card hiển thị thông tin
      expect(find.text('ThS.BS Nguyễn Văn Minh'), findsOneWidget);
      expect(find.text('Khoa Ngoại'), findsOneWidget);
      expect(find.text('180.000 đ'), findsOneWidget);
      expect(find.text('12 năm kinh nghiệm'), findsOneWidget);

      // Bấm vào card
      await tester.tap(find.byType(DoctorSearchCard));
      await tester.pumpAndSettle();

      expect(capturedDoctorId, 42);
      expect(find.text('Chi tiết bác sĩ'), findsOneWidget);
    });

    testWidgets('DoctorSearchPage nhận từ khóa ban đầu qua arguments và tự tìm kiếm ngay không debounce', (tester) async {
      final requestedKeywords = <String?>[];

      final mockClient = MockClient((request) async {
        requestedKeywords.add(request.url.queryParameters['keyword']);
        final res = {
          'items': [
            sampleDoctorJson(id: 1, name: 'BS Lan', qualification: 'ThS'),
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
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/doctors/search',
                      arguments: 'Lan',
                    ),
                    child: const Text('Đi tới tìm kiếm'),
                  ),
                ),
            '/doctors/search': (context) {
              final keyword = ModalRoute.of(context)?.settings.arguments as String?;
              return DoctorSearchPage(
                repository: repo,
                initialKeyword: keyword,
              );
            },
          },
        ),
      );

      await tester.tap(find.text('Đi tới tìm kiếm'));
      await tester.pumpAndSettle();

      // Kiểm tra TextField hiển thị đúng từ khóa ban đầu
      expect(find.widgetWithText(TextField, 'Lan'), findsOneWidget);

      // Đã gọi API ngay lập tức mà không cần chờ debounce 500ms
      expect(requestedKeywords.length, 1);
      expect(requestedKeywords.first, 'Lan');
      expect(find.text('ThS BS Lan'), findsOneWidget);
    });

    testWidgets('Trang chủ truyền từ khóa đã gõ sang /doctors/search khi bấm kính lúp', (tester) async {
      String? capturedArg;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HealthcareFunctionsPanel(onSelected: (_) {}),
            ),
          ),
          routes: {
            '/doctors/search': (context) {
              capturedArg = ModalRoute.of(context)?.settings.arguments as String?;
              return const Scaffold(body: Text('Trang tìm kiếm bác sĩ'));
            },
          },
        ),
      );

      // Mở thanh tìm kiếm trên trang chủ
      await tester.tap(find.byTooltip('Tìm kiếm chức năng'));
      await tester.pumpAndSettle();

      // Gõ từ khóa tìm kiếm
      await tester.enterText(find.byType(TextField), 'Bác sĩ A');
      await tester.pump();

      // Bấm icon kính lúp trên thanh search
      await tester.tap(find.byTooltip('Tìm kiếm bác sĩ'));
      await tester.pumpAndSettle();

      expect(capturedArg, 'Bác sĩ A');
      expect(find.text('Trang tìm kiếm bác sĩ'), findsOneWidget);
    });

    testWidgets('DoctorSearchPage hiển thị "Không tìm thấy bác sĩ nào" khi danh sách rỗng', (tester) async {
      final mockClient = MockClient((request) async {
        final res = {
          'items': <dynamic>[],
          'totalCount': 0,
          'page': 1,
          'pageSize': 10,
          'totalPages': 0,
          'hasPreviousPage': false,
          'hasNextPage': false,
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(res)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSearchPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy bác sĩ nào'), findsOneWidget);
      expect(find.text('Thử tìm kiếm với từ khóa khác'), findsOneWidget);
    });

    testWidgets('DoctorSearchPage hiển thị lỗi và nút "Thử lại" hoạt động chính xác', (tester) async {
      var attemptCount = 0;

      final mockClient = MockClient((request) async {
        attemptCount++;
        if (attemptCount == 1) {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'message': 'Máy chủ đang bận, vui lòng thử lại sau'})),
            500,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }

        final res = {
          'items': [sampleDoctorJson(id: 1, name: 'Lê Văn C', qualification: 'BS')],
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
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSearchPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Hiển thị thông báo lỗi từ server và nút thử lại
      expect(find.text('Máy chủ đang bận, vui lòng thử lại sau'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Bấm nút thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(attemptCount, 2);
      expect(find.text('BS Lê Văn C'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
    });

    testWidgets('Debounce 500ms trì hoãn gọi hàm tìm kiếm cho đến khi ngừng gõ đủ 500ms', (tester) async {
      var callCount = 0;
      Timer? debounceTimer;

      void onSearchChanged(String query) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 500), () {
          callCount++;
        });
      }

      // Người dùng gõ 'N'
      onSearchChanged('N');
      await tester.pump(const Duration(milliseconds: 200));
      expect(callCount, 0);

      // Người dùng gõ tiếp 'Ng'
      onSearchChanged('Ng');
      await tester.pump(const Duration(milliseconds: 200));
      expect(callCount, 0);

      // Người dùng gõ tiếp 'Nguyễn'
      onSearchChanged('Nguyễn');
      await tester.pump(const Duration(milliseconds: 490));
      expect(callCount, 0);

      // Đủ 500ms sau lần gõ cuối cùng
      await tester.pump(const Duration(milliseconds: 20));
      expect(callCount, 1);

      debounceTimer?.cancel();
    });

    testWidgets('Debounce 500ms trên TextField và hủy request cũ khi đổi từ khóa', (tester) async {
      final requestedKeywords = <String?>[];

      final mockClient = MockClient((request) async {
        requestedKeywords.add(request.url.queryParameters['keyword']);
        final kw = request.url.queryParameters['keyword'];
        final res = {
          'items': [
            sampleDoctorJson(
              id: 1,
              name: kw ?? 'Mặc định',
              qualification: 'BS',
            ),
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
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.api');
      final repo = DoctorRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSearchPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(requestedKeywords.length, 1); // Lần gọi ban đầu

      // Nhập chữ 'A'
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump(const Duration(milliseconds: 200));
      // Chưa đủ 500ms debounce nên chưa gọi API lần 2
      expect(requestedKeywords.length, 1);

      // Nhập tiếp chữ 'An' trước khi hết 500ms
      await tester.enterText(find.byType(TextField), 'An');
      await tester.pump(const Duration(milliseconds: 200));
      expect(requestedKeywords.length, 1);

      // Chờ thêm 350ms (tổng hơn 500ms tính từ lần gõ 'An')
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Đã gọi API với từ khóa 'An'
      expect(requestedKeywords.length, 2);
      expect(requestedKeywords.last, 'An');
      expect(find.text('BS An'), findsOneWidget);
    });
  });
}
