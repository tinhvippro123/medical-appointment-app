import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/core/network/api_exception.dart';
import 'package:medical_appointment_app/core/theme/app_theme.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/main.dart';
import 'package:medical_appointment_app/models/order.dart';
import 'package:medical_appointment_app/models/user_role_models.dart';
import 'package:medical_appointment_app/repositories/admin_order_repository.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/repositories/doctor_repository.dart';
import 'package:medical_appointment_app/repositories/role_repository.dart';
import 'package:medical_appointment_app/repositories/user_repository.dart';
import 'package:medical_appointment_app/screens/admin/admin_dashboard_page.dart';
import 'package:medical_appointment_app/screens/admin/orders/admin_order_detail_page.dart';
import 'package:medical_appointment_app/screens/admin/orders/admin_order_page.dart';
import 'package:medical_appointment_app/screens/admin/orders/widgets/order_status_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

String createFakeJwt(String role) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'Role': role, 'sub': '1'})))
      .replaceAll('=', '');
  return '$header.$payload.sig';
}

Map<String, dynamic> sampleOrderDetailItemJson({
  int id = 101,
  int orderId = 1,
  int doctorId = 5,
  String doctorFullName = 'BS Nguyễn Minh Anh',
  String departmentName = 'Nội tổng quát',
  String? roomNumber = '102',
  int patientProfileId = 12,
  String patientProfileFullName = 'Trần Văn Bình',
  String appointmentDate = '2026-11-26',
  String timeSlot = '08:00-09:00',
  int queueNumber = 3,
  double fee = 150000,
  String? note = 'Khám tổng quát',
  String status = 'Pending',
}) => {
  'id': id,
  'orderId': orderId,
  'doctorId': doctorId,
  'doctorFullName': doctorFullName,
  'departmentName': departmentName,
  'roomNumber': roomNumber,
  'patientProfileId': patientProfileId,
  'patientProfileFullName': patientProfileFullName,
  'appointmentDate': appointmentDate,
  'timeSlot': timeSlot,
  'queueNumber': queueNumber,
  'fee': fee,
  'note': note,
  'status': status,
  'createdAt': '2026-11-25T10:30:00',
};

Map<String, dynamic> sampleOrderJson({
  int id = 1,
  int userId = 2,
  String userFullName = 'Nguyễn Văn An',
  double totalAmount = 300000,
  String status = 'Pending',
  String? cancellationReason,
  String paymentMethod = 'Cash',
  String paymentStatus = 'Unpaid',
  String? transactionId,
  String createdAt = '2026-11-25T14:30:00',
  String? updatedAt,
  List<Map<String, dynamic>>? orderDetails,
}) => {
  'id': id,
  'userId': userId,
  'userFullName': userFullName,
  'totalAmount': totalAmount,
  'status': status,
  'cancellationReason': cancellationReason,
  'paymentMethod': paymentMethod,
  'paymentStatus': paymentStatus,
  'transactionId': transactionId,
  'createdAt': createdAt,
  'updatedAt': updatedAt,
  'orderDetails': ?orderDetails,
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

  void configureScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionHepler.saveToken(createFakeJwt('ADMIN'));
  });

  group('1. Model Order, OrderDetail & OrderStatus Unit Tests', () {
    test('Order.fromJson parse đầy đủ OrderResponse + OrderDetails và định dạng', () {
      final order = Order.fromJson(
        sampleOrderJson(
          id: 15,
          userId: 7,
          userFullName: 'Lê Thị Hoa',
          totalAmount: 350000,
          status: 'Confirmed',
          paymentMethod: 'VNPay',
          paymentStatus: 'Paid',
          transactionId: 'VNP123456',
          createdAt: '2026-11-25T07:15:00Z',
          orderDetails: [
            sampleOrderDetailItemJson(
              id: 201,
              orderId: 15,
              fee: 350000,
              status: 'Confirmed',
            ),
          ],
        ),
      );

      expect(order.id, 15);
      expect(order.userId, 7);
      expect(order.userFullName, 'Lê Thị Hoa');
      expect(order.totalAmount, 350000);
      expect(order.totalAmountFormatted, '350.000 đ');
      expect(order.status, 'Confirmed');
      expect(order.statusLabel, 'Đã xác nhận');
      expect(order.paymentMethodLabel, 'VNPay');
      expect(order.paymentStatusLabel, 'Đã thanh toán');
      expect(order.isPaid, isTrue);
      expect(order.transactionId, 'VNP123456');
      // 07:15 UTC -> 14:15 UTC+7
      expect(order.createdAtFormatted, '25/11/2026 14:15');

      expect(order.orderDetails.length, 1);
      final detail = order.orderDetails.first;
      expect(detail.doctorFullName, 'BS Nguyễn Minh Anh');
      expect(detail.departmentName, 'Nội tổng quát');
      expect(detail.roomDisplay, 'Phòng 102');
      expect(detail.patientProfileFullName, 'Trần Văn Bình');
      expect(detail.appointmentDateFormatted, '26/11/2026');
      expect(detail.timeSlot, '08:00-09:00');
      expect(detail.queueNumber, 3);
      expect(detail.feeFormatted, '350.000 đ');
    });

    test('Order.fromJson parse an toàn với dữ liệu thiếu/null/kiểu lạ', () {
      final order = Order.fromJson({
        'id': '9',
        'userId': null,
        'user': {'fullName': 'Tên từ nested user'},
        'totalAmount': '200000',
        'status': 2, // enum số fallback -> Completed
        'paymentMethod': null,
        'paymentStatus': null,
        'orderDetails': null,
      });

      expect(order.id, 9);
      expect(order.userId, 0);
      expect(order.userFullName, 'Tên từ nested user');
      expect(order.totalAmount, 200000);
      expect(order.status, 'Completed');
      expect(order.statusLabel, 'Hoàn thành');
      expect(order.orderDetails, isEmpty);
      expect(order.createdAtFormatted, 'Chưa cập nhật');
    });

    test('OrderStatus.allowedNextStatuses trả về đúng chuyển trạng thái hợp lệ', () {
      expect(
        OrderStatus.allowedNextStatuses('Pending'),
        ['Confirmed', 'Cancelled'],
      );
      expect(
        OrderStatus.allowedNextStatuses('Confirmed'),
        ['Completed', 'Cancelled'],
      );
      expect(OrderStatus.allowedNextStatuses('Completed'), isEmpty);
      expect(OrderStatus.allowedNextStatuses('Cancelled'), isEmpty);
    });
  });

  group('2. AdminOrderRepository Unit Tests', () {
    test('GET /api/admin/orders (có & không lọc status) và GET /api/admin/orders/{id}', () async {
      final capturedRequests = <http.Request>[];

      final mockClient = MockClient((request) async {
        capturedRequests.add(request);

        if (request.method == 'GET' && request.url.path == '/api/admin/orders') {
          return jsonResponse({
            'items': [
              sampleOrderJson(id: 10, userFullName: 'Trần A', status: 'Pending'),
              sampleOrderJson(id: 11, userFullName: 'Phạm B', status: 'Pending'),
            ],
            'totalCount': 2,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        }

        if (request.method == 'GET' && request.url.path == '/api/admin/orders/10') {
          return jsonResponse(
            sampleOrderJson(
              id: 10,
              userFullName: 'Trần A',
              orderDetails: [sampleOrderDetailItemJson(orderId: 10)],
            ),
          );
        }

        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      final pagedAll = await repo.getOrders(page: 1, pageSize: 10);
      expect(pagedAll.items.length, 2);
      expect(capturedRequests.last.headers['Authorization'], 'Bearer admin_jwt');
      expect(capturedRequests.last.url.queryParameters.containsKey('status'), isFalse);

      final pagedFiltered = await repo.getOrders(
        page: 2,
        pageSize: 5,
        status: 'Pending',
      );
      expect(pagedFiltered.items.first.userFullName, 'Trần A');
      expect(capturedRequests.last.url.queryParameters, {
        'page': '2',
        'pageSize': '5',
        'status': 'Pending',
      });

      final detail = await repo.getOrderById(10);
      expect(detail.id, 10);
      expect(detail.orderDetails.length, 1);
    });

    test('PUT /api/admin/orders/{id}/status thành công (Confirmed & Cancelled) và lỗi chuyển sai', () async {
      final capturedBodies = <Map<String, dynamic>>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/api/admin/orders/1/status') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedBodies.add(body);

          if (body['status'] == 'Pending') {
            return jsonResponse(
              {
                'statusCode': 400,
                'errorCode': 'INVALID_ORDER_STATUS_TRANSITION',
                'message': 'Chuyển trạng thái đơn hàng không hợp lệ!',
              },
              statusCode: 400,
            );
          }

          return jsonResponse(
            sampleOrderJson(
              id: 1,
              status: body['status'] as String,
              cancellationReason: body['cancellationReason'] as String?,
              paymentStatus: 'Unpaid', // PaymentStatus giữ nguyên
              orderDetails: [
                sampleOrderDetailItemJson(
                  orderId: 1,
                  status: body['status'] as String,
                ),
              ],
            ),
          );
        }

        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      final confirmed = await repo.updateOrderStatus(1, status: 'Confirmed');
      expect(confirmed.status, 'Confirmed');
      expect(confirmed.paymentStatus, 'Unpaid');
      expect(capturedBodies.first, {'status': 'Confirmed'});
      expect(capturedBodies.first.containsKey('cancellationReason'), isFalse);

      final cancelled = await repo.updateOrderStatus(
        1,
        status: 'Cancelled',
        cancellationReason: 'Bệnh nhân yêu cầu hủy',
      );
      expect(cancelled.status, 'Cancelled');
      expect(cancelled.cancellationReason, 'Bệnh nhân yêu cầu hủy');
      expect(capturedBodies[1], {
        'status': 'Cancelled',
        'cancellationReason': 'Bệnh nhân yêu cầu hủy',
      });

      await expectLater(
        () => repo.updateOrderStatus(1, status: 'Pending'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.errorCode,
                'errorCode',
                'INVALID_ORDER_STATUS_TRANSITION',
              )
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'Chuyển trạng thái đơn hàng không hợp lệ!',
              ),
        ),
      );
    });
  });

  group('3. OrderStatusChip Widget Tests', () {
    testWidgets('Hiển thị đúng nhãn và màu sắc riêng cho 4 trạng thái', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OrderStatusChip(key: ValueKey('chip-pending'), status: 'Pending'),
                OrderStatusChip(key: ValueKey('chip-confirmed'), status: 'Confirmed'),
                OrderStatusChip(key: ValueKey('chip-completed'), status: 'Completed'),
                OrderStatusChip(key: ValueKey('chip-cancelled'), status: 'Cancelled'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(find.text('Hoàn thành'), findsOneWidget);
      expect(find.text('Đã hủy'), findsOneWidget);

      Container containerOf(String key) => tester.widget<Container>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Container),
        ),
      );

      final pendingDeco =
          containerOf('chip-pending').decoration! as BoxDecoration;
      final confirmedDeco =
          containerOf('chip-confirmed').decoration! as BoxDecoration;
      final completedDeco =
          containerOf('chip-completed').decoration! as BoxDecoration;
      final cancelledDeco =
          containerOf('chip-cancelled').decoration! as BoxDecoration;

      // Pending=vàng, Confirmed=xanh, Completed=xám, Cancelled=đỏ
      expect(pendingDeco.color, const Color(0xfffef3c7));
      expect(confirmedDeco.color, const Color(0xffdbeafe));
      expect(completedDeco.color, const Color(0xfff1f5f9));
      expect(cancelledDeco.color, const Color(0xfffee2e2));

      final bgColors = {
        pendingDeco.color,
        confirmedDeco.color,
        completedDeco.color,
        cancelledDeco.color,
      };
      expect(bgColors.length, 4);
    });
  });

  group('4. AdminOrderPage Widget Tests (4 trạng thái, quyền ADMIN, lọc, lazy load, refresh)', () {
    testWidgets('Chặn truy cập khi không phải ADMIN (SessionHepler.isAdmin = false)', (
      tester,
    ) async {
      configureScreenSize(tester);
      await SessionHepler.saveToken(createFakeJwt('PATIENT'));
      var apiCalled = false;

      final mockClient = MockClient((_) async {
        apiCalled = true;
        return jsonResponse({});
      });
      final repo = AdminOrderRepository(
        apiClient: ApiClient(client: mockClient, baseUrl: 'http://test.api'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(apiCalled, isFalse);
      expect(find.text('Bạn không có quyền truy cập'), findsOneWidget);
      expect(
        find.text(
          'Chỉ Quản trị viên (ADMIN) mới được phép quản lý đơn đặt lịch.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Hiển thị loading, lỗi + Thử lại thành công, và trạng thái rỗng', (
      tester,
    ) async {
      configureScreenSize(tester);
      final firstCompleter = Completer<http.Response>();
      var attempt = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/admin/orders') {
          attempt++;
          if (attempt == 1) {
            return firstCompleter.future;
          }
          return jsonResponse({
            'items': [],
            'totalCount': 0,
            'page': 1,
            'pageSize': 10,
            'totalPages': 0,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderPage(repository: repo),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 1. Loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 2. Error
      firstCompleter.complete(
        jsonResponse(
          {
            'statusCode': 500,
            'errorCode': 'INTERNAL_SERVER_ERROR',
            'message': 'Đã xảy ra lỗi hệ thống nghiêm trọng!',
          },
          statusCode: 500,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã xảy ra lỗi hệ thống nghiêm trọng!'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Bấm Thử lại -> trả về danh sách rỗng (3. Empty)
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(attempt, 2);
      expect(find.text('Chưa có đơn đặt lịch nào'), findsOneWidget);
      expect(find.text('Tải lại danh sách'), findsOneWidget);
    });

    testWidgets('Hiển thị dữ liệu, lọc theo trạng thái, lazy loading và pull-to-refresh', (
      tester,
    ) async {
      configureScreenSize(tester);
      final requests = <Uri>[];

      final mockClient = MockClient((request) async {
        requests.add(request.url);
        final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
        final statusFilter = request.url.queryParameters['status'];

        if (statusFilter == 'Confirmed') {
          return jsonResponse({
            'items': [
              sampleOrderJson(
                id: 99,
                userFullName: 'Khách Đã Xác Nhận',
                status: 'Confirmed',
                totalAmount: 500000,
              ),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        }

        if (page == 1) {
          return jsonResponse({
            'items': List.generate(
              15,
              (i) => sampleOrderJson(
                id: i + 1,
                userFullName: 'Khách Hàng ${i + 1}',
                status: 'Pending',
                totalAmount: 200000,
              ),
            ),
            'totalCount': 16,
            'page': 1,
            'pageSize': 15,
            'totalPages': 2,
            'hasPreviousPage': false,
            'hasNextPage': true,
          });
        }

        return jsonResponse({
          'items': [
            sampleOrderJson(
              id: 16,
              userFullName: 'Khách Hàng Trang 2',
              status: 'Completed',
              totalAmount: 450000,
            ),
          ],
          'totalCount': 16,
          'page': 2,
          'pageSize': 15,
          'totalPages': 2,
          'hasPreviousPage': true,
          'hasNextPage': false,
        });
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra dữ liệu trang 1 (tên user, ngày đặt, trạng thái, tổng tiền)
      expect(find.text('Khách Hàng 1'), findsOneWidget);
      expect(find.text('Ngày đặt: 25/11/2026 14:30'), findsWidgets);
      expect(find.text('200.000 đ'), findsWidgets);

      // Scroll xuống cuối để kích hoạt lazy loading trang 2
      for (var attempt = 0;
          attempt < 5 && !requests.any((u) => u.queryParameters['page'] == '2');
          attempt++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
      }

      expect(requests.any((u) => u.queryParameters['page'] == '2'), isTrue);
      await tester.scrollUntilVisible(
        find.text('Khách Hàng Trang 2'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(find.text('Khách Hàng Trang 2'), findsOneWidget);
      expect(find.text('450.000 đ'), findsOneWidget);

      // Lọc theo trạng thái Confirmed
      final confirmedFilter = find.byKey(const ValueKey('order-filter-Confirmed'));
      await tester.ensureVisible(confirmedFilter);
      await tester.pumpAndSettle();
      await tester.tap(confirmedFilter);
      await tester.pumpAndSettle();

      expect(find.text('Khách Đã Xác Nhận'), findsOneWidget);
      expect(find.text('500.000 đ'), findsOneWidget);
      expect(requests.last.queryParameters['status'], 'Confirmed');

      // Pull-to-refresh gọi lại trang 1
      final countBeforeRefresh = requests.length;
      await tester.fling(find.byType(ListView), const Offset(0, 700), 1000);
      await tester.pumpAndSettle();
      expect(requests.length, greaterThan(countBeforeRefresh));
      expect(requests.last.queryParameters['page'], '1');
    });

    testWidgets('Bấm đơn mở chi tiết, đổi trạng thái, quay lại tự tải lại danh sách', (
      tester,
    ) async {
      configureScreenSize(tester);
      var currentStatus = 'Pending';
      var listCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/admin/orders') {
          listCalls++;
          return jsonResponse({
            'items': [
              sampleOrderJson(
                id: 5,
                userFullName: 'Nguyễn Văn Tâm',
                status: currentStatus,
                totalAmount: 150000,
              ),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        }
        if (request.method == 'GET' && request.url.path == '/api/admin/orders/5') {
          return jsonResponse(
            sampleOrderJson(
              id: 5,
              userFullName: 'Nguyễn Văn Tâm',
              status: currentStatus,
              totalAmount: 150000,
              orderDetails: [
                sampleOrderDetailItemJson(orderId: 5, status: currentStatus),
              ],
            ),
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/admin/orders/5/status') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          currentStatus = body['status'] as String;
          return jsonResponse(
            sampleOrderJson(
              id: 5,
              userFullName: 'Nguyễn Văn Tâm',
              status: currentStatus,
              totalAmount: 150000,
              orderDetails: [
                sampleOrderDetailItemJson(orderId: 5, status: currentStatus),
              ],
            ),
          );
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(listCalls, 1);

      // Bấm vào card đơn #5
      final orderCard = find.byKey(const ValueKey('order-card-5'));
      await tester.ensureVisible(orderCard);
      await tester.pumpAndSettle();
      await tester.tap(orderCard);
      await tester.pumpAndSettle();

      // Kiểm tra chi tiết OrderDetails
      expect(find.byType(AdminOrderDetailPage), findsOneWidget);
      expect(find.text('BS Nguyễn Minh Anh'), findsOneWidget);
      expect(find.text('STT #3'), findsOneWidget);

      // Đổi trạng thái sang Confirmed
      final dropdownFinder = find.byKey(const ValueKey('order-status-dropdown'));
      await tester.ensureVisible(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final confirmedItem = find.text('Đã xác nhận').last;
      await tester.ensureVisible(confirmedItem);
      await tester.pumpAndSettle();
      await tester.tap(confirmedItem);
      await tester.pumpAndSettle();

      // Confirm dialog -> bấm Xác nhận
      expect(find.text('Xác nhận đổi trạng thái'), findsOneWidget);
      final confirmBtn = find.byKey(const ValueKey('confirm-status-change-button'));
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Quay lại danh sách -> tự động reload (listCalls == 2) và thấy chip Đã xác nhận
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(listCalls, 2);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('order-card-5')),
          matching: find.text('Đã xác nhận'),
        ),
        findsOneWidget,
      );
    });
  });

  group('5. AdminOrderDetailPage Dropdown hợp lệ, Dialog Lý do hủy, Confirm, Chống bấm đúp & Lỗi', () {
    testWidgets('Dropdown chỉ hiện trạng thái hợp lệ cho Pending, Confirmed, Completed, Cancelled', (
      tester,
    ) async {
      configureScreenSize(tester);

      Future<void> pumpDetailWithStatus(String status) async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/admin/orders/1') {
            return jsonResponse(
              sampleOrderJson(
                id: 1,
                status: status,
                orderDetails: [sampleOrderDetailItemJson(status: status)],
              ),
            );
          }
          return jsonResponse({}, statusCode: 404);
        });
        final repo = AdminOrderRepository(
          apiClient: ApiClient(
            client: mockClient,
            baseUrl: 'http://test.api',
            tokenProvider: () async => 'admin_jwt',
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AdminOrderDetailPage(
              key: ValueKey('detail-$status'),
              orderId: 1,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // 1. Pending -> chỉ có Confirmed & Cancelled
      await pumpDetailWithStatus('Pending');
      var dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('order-status-dropdown')),
      );
      expect(
        dropdown.items!.map((e) => e.value).toList(),
        ['Confirmed', 'Cancelled'],
      );

      // 2. Confirmed -> chỉ có Completed & Cancelled
      await pumpDetailWithStatus('Confirmed');
      dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('order-status-dropdown')),
      );
      expect(
        dropdown.items!.map((e) => e.value).toList(),
        ['Completed', 'Cancelled'],
      );

      // 3. Completed -> không cho chọn trạng thái tiếp
      await pumpDetailWithStatus('Completed');
      expect(
        find.byKey(const ValueKey('order-status-dropdown')),
        findsNothing,
      );
      expect(
        find.textContaining('không thể chuyển trạng thái tiếp'),
        findsOneWidget,
      );

      // 4. Cancelled -> không cho chọn trạng thái tiếp
      await pumpDetailWithStatus('Cancelled');
      expect(
        find.byKey(const ValueKey('order-status-dropdown')),
        findsNothing,
      );
    });

    testWidgets('Chọn Cancelled -> bắt buộc nhập Lý do hủy -> Confirm dialog -> PUT thành công', (
      tester,
    ) async {
      configureScreenSize(tester);
      final putBodies = <Map<String, dynamic>>[];
      var currentStatus = 'Pending';
      String? currentReason;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/admin/orders/1') {
          return jsonResponse(
            sampleOrderJson(
              id: 1,
              status: currentStatus,
              cancellationReason: currentReason,
              orderDetails: [sampleOrderDetailItemJson(status: currentStatus)],
            ),
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/admin/orders/1/status') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          putBodies.add(body);
          currentStatus = body['status'] as String;
          currentReason = body['cancellationReason'] as String?;
          return jsonResponse(
            sampleOrderJson(
              id: 1,
              status: currentStatus,
              cancellationReason: currentReason,
              orderDetails: [sampleOrderDetailItemJson(status: currentStatus)],
            ),
          );
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderDetailPage(orderId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Mở dropdown và chọn Đã hủy
      final dropdownFinder = find.byKey(const ValueKey('order-status-dropdown'));
      await tester.ensureVisible(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final cancelOption = find.text('Đã hủy').last;
      await tester.ensureVisible(cancelOption);
      await tester.pumpAndSettle();
      await tester.tap(cancelOption);
      await tester.pumpAndSettle();

      // Dialog nhập lý do hủy xuất hiện
      expect(find.text('Lý do hủy đơn'), findsOneWidget);

      // Thử bấm Tiếp tục khi chưa nhập -> báo lỗi bắt buộc nhập
      final reasonSubmitBtn = find.byKey(
        const ValueKey('cancellation-reason-submit-button'),
      );
      await tester.ensureVisible(reasonSubmitBtn);
      await tester.pumpAndSettle();
      await tester.tap(reasonSubmitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập lý do hủy'), findsOneWidget);
      expect(putBodies, isEmpty);

      // Nhập chỉ khoảng trắng -> vẫn lỗi
      final reasonField = find.byKey(const ValueKey('cancellation-reason-field'));
      await tester.enterText(reasonField, '   ');
      await tester.tap(reasonSubmitBtn);
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do hủy'), findsOneWidget);

      // Nhập lý do hợp lệ -> Tiếp tục -> Confirm dialog
      await tester.enterText(reasonField, 'Bác sĩ bận công tác');
      await tester.tap(reasonSubmitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận đổi trạng thái'), findsOneWidget);
      expect(find.text('Lý do hủy: Bác sĩ bận công tác'), findsOneWidget);

      // Bấm Xác nhận
      final confirmBtn = find.byKey(const ValueKey('confirm-status-change-button'));
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(putBodies.length, 1);
      expect(putBodies.first, {
        'status': 'Cancelled',
        'cancellationReason': 'Bác sĩ bận công tác',
      });
      expect(
        find.text('Cập nhật trạng thái đơn đặt lịch thành công.'),
        findsOneWidget,
      );
      expect(find.text('Lý do hủy: Bác sĩ bận công tác'), findsOneWidget);
    });

    testWidgets('Chống bấm đúp khi đang gửi PUT và hiển thị lỗi backend khi chuyển sai', (
      tester,
    ) async {
      configureScreenSize(tester);
      final putCompleter = Completer<http.Response>();
      var putCalls = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/admin/orders/1') {
          return jsonResponse(
            sampleOrderJson(
              id: 1,
              status: 'Pending',
              orderDetails: [sampleOrderDetailItemJson(status: 'Pending')],
            ),
          );
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/admin/orders/1/status') {
          putCalls++;
          return putCompleter.future;
        }
        return jsonResponse({}, statusCode: 404);
      });

      final repo = AdminOrderRepository(
        apiClient: ApiClient(
          client: mockClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminOrderDetailPage(orderId: 1, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinder = find.byKey(const ValueKey('order-status-dropdown'));
      await tester.ensureVisible(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final confirmedOption = find.text('Đã xác nhận').last;
      await tester.ensureVisible(confirmedOption);
      await tester.pumpAndSettle();
      await tester.tap(confirmedOption);
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const ValueKey('confirm-status-change-button'));
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Đang gửi PUT -> khóa dropdown (onChanged == null) & hiện loading text
      expect(
        tester.widget<DropdownButton<String>>(dropdownFinder).onChanged,
        isNull,
      );
      expect(find.text('Đang cập nhật trạng thái...'), findsOneWidget);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pump();
      expect(putCalls, 1);

      // Backend trả lỗi chuyển trạng thái sai (400)
      putCompleter.complete(
        jsonResponse(
          {
            'statusCode': 400,
            'errorCode': 'INVALID_ORDER_STATUS_TRANSITION',
            'message': 'Chuyển trạng thái đơn hàng không hợp lệ!',
          },
          statusCode: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chuyển trạng thái đơn hàng không hợp lệ!'),
        findsOneWidget,
      );
      // Mở khóa dropdown trở lại và vẫn giữ trạng thái Pending
      expect(
        tester.widget<DropdownButton<String>>(dropdownFinder).onChanged,
        isNotNull,
      );
      expect(
        find.descendant(
          of: find.byType(OrderStatusChip).first,
          matching: find.text('Chờ xác nhận'),
        ),
        findsOneWidget,
      );
    });
  });

  group('6. Route /admin/orders & AdminDashboardPage Navigation Tests', () {
    testWidgets('AdminDashboardPage có thẻ Lịch hẹn và bấm vào mở AdminOrderPage', (
      tester,
    ) async {
      configureScreenSize(tester);
      // Dùng role PATIENT trong SharedPreferences để tránh AdminOrderPage mặc định gọi mạng thật,
      // đồng thời truyền currentUser ADMIN để dựng AdminDashboardPage.
      await SessionHepler.saveToken(createFakeJwt('PATIENT'));

      final statsClient = MockClient((request) async {
        if (request.url.path == '/api/users') {
          return jsonResponse({
            'items': [],
            'totalCount': 4,
            'page': 1,
            'pageSize': 1,
            'totalPages': 4,
            'hasPreviousPage': false,
            'hasNextPage': true,
          });
        }
        if (request.url.path == '/api/roles') {
          return jsonResponse([
            {'id': 1, 'key': 'ADMIN', 'name': 'Quản trị viên', 'userCount': 1},
            {'id': 2, 'key': 'PATIENT', 'name': 'Bệnh nhân', 'userCount': 3},
          ]);
        }
        if (request.url.path == '/api/departments') {
          return jsonResponse([
            {'id': 1, 'name': 'Nội tổng quát'},
          ]);
        }
        if (request.url.path == '/api/doctors') {
          return jsonResponse({
            'items': [],
            'totalCount': 6,
            'page': 1,
            'pageSize': 1,
            'totalPages': 6,
            'hasPreviousPage': false,
            'hasNextPage': true,
          });
        }
        return jsonResponse({}, statusCode: 404);
      });

      final authRepo = AuthRepository(
        baseUrl: 'http://test.api',
        token: () async => 'admin_jwt',
        client: statsClient,
      );
      final userRepo = UserRepository(
        baseUrl: 'http://test.api',
        token: () async => 'admin_jwt',
        enableCache: false,
        client: statsClient,
      );
      final roleRepo = RoleRepository(
        baseUrl: 'http://test.api',
        token: () async => 'admin_jwt',
        enableCache: false,
        client: statsClient,
      );
      final deptRepo = DepartmentRepository(
        baseUrl: 'http://test.api',
        token: () async => 'admin_jwt',
        client: statsClient,
      );
      final doctorRepo = DoctorRepository(
        apiClient: ApiClient(
          client: statsClient,
          baseUrl: 'http://test.api',
          tokenProvider: () async => 'admin_jwt',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardPage(
            currentUser: const SessionUser(
              userId: 1,
              fullName: 'Admin Hệ Thống',
              phone: '0900000001',
              roleKey: 'ADMIN',
            ),
            authRepository: authRepo,
            userRepository: userRepo,
            roleRepository: roleRepo,
            departmentRepository: deptRepo,
            doctorRepository: doctorRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final orderTile = find.text('Lịch hẹn');
      expect(orderTile, findsOneWidget);
      expect(find.text('Đơn đặt lịch'), findsOneWidget);

      await tester.ensureVisible(orderTile);
      await tester.pumpAndSettle();
      await tester.tap(orderTile);
      await tester.pumpAndSettle();

      expect(find.byType(AdminOrderPage), findsOneWidget);
    });

    testWidgets('Route /admin/orders trong MyApp điều hướng đúng sang AdminOrderPage', (
      tester,
    ) async {
      configureScreenSize(tester);
      await SessionHepler.saveToken(createFakeJwt('PATIENT'));

      await tester.pumpWidget(
        MyApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/admin/orders'),
                  child: const Text('Mở quản lý lịch hẹn'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở quản lý lịch hẹn'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminOrderPage), findsOneWidget);
    });
  });

  group('7. Tìm kiếm theo từ khóa & Lọc theo khoảng ngày (Card A13)', () {
    test(
      'AdminOrderRepository.getOrders truyền đúng keyword, fromDate, toDate và bỏ qua từ khóa rỗng',
      () async {
        final capturedUris = <Uri>[];
        final mockClient = MockClient((request) async {
          capturedUris.add(request.url);
          return jsonResponse({
            'items': [
              sampleOrderJson(id: 25, userFullName: 'Lê Thanh Tính'),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        });

        final repo = AdminOrderRepository(
          apiClient: ApiClient(
            client: mockClient,
            baseUrl: 'http://test.api',
            tokenProvider: () async => 'admin_jwt',
          ),
        );

        await repo.getOrders(
          page: 1,
          pageSize: 10,
          status: 'Confirmed',
          keyword: '  0987654321  ',
          fromDate: DateTime(2026, 11, 1),
          toDate: DateTime(2026, 11, 25),
        );

        expect(capturedUris.last.queryParameters, {
          'page': '1',
          'pageSize': '10',
          'status': 'Confirmed',
          'keyword': '0987654321',
          'fromDate': '2026-11-01',
          'toDate': '2026-11-25',
        });

        await repo.getOrders(
          page: 1,
          pageSize: 10,
          keyword: '   ',
        );

        expect(capturedUris.last.queryParameters, {
          'page': '1',
          'pageSize': '10',
        });
      },
    );

    testWidgets(
      'AdminOrderPage tìm kiếm theo từ khóa (tên/SĐT/#mã) và xóa từ khóa tải lại danh sách',
      (tester) async {
        configureScreenSize(tester);
        final requests = <Uri>[];

        final mockClient = MockClient((request) async {
          requests.add(request.url);
          final kw = request.url.queryParameters['keyword'];
          if (kw == '#15') {
            return jsonResponse({
              'items': [
                sampleOrderJson(
                  id: 15,
                  userFullName: 'Nguyễn Thị Mai',
                  status: 'Confirmed',
                ),
              ],
              'totalCount': 1,
              'page': 1,
              'pageSize': 10,
              'totalPages': 1,
              'hasPreviousPage': false,
              'hasNextPage': false,
            });
          }

          return jsonResponse({
            'items': [
              sampleOrderJson(id: 1, userFullName: 'Khách Mặc Định'),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        });

        final repo = AdminOrderRepository(
          apiClient: ApiClient(
            client: mockClient,
            baseUrl: 'http://test.api',
            tokenProvider: () async => 'admin_jwt',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AdminOrderPage(repository: repo),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Khách Mặc Định'), findsOneWidget);

        final searchField = find.byKey(
          const ValueKey('admin-order-search-field'),
        );
        await tester.enterText(searchField, '  #15  ');
        await tester.pump();

        await tester.tap(
          find.byKey(const ValueKey('admin-order-submit-search')),
        );
        await tester.pumpAndSettle();

        expect(requests.last.queryParameters['keyword'], '#15');
        expect(requests.last.queryParameters['page'], '1');
        expect(find.text('Nguyễn Thị Mai'), findsOneWidget);
        expect(find.text('Khách Mặc Định'), findsNothing);

        // Xóa từ khóa -> gọi lại trang 1 không kèm keyword
        await tester.tap(
          find.byKey(const ValueKey('admin-order-clear-search')),
        );
        await tester.pumpAndSettle();

        expect(requests.last.queryParameters.containsKey('keyword'), isFalse);
        expect(find.text('Khách Mặc Định'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminOrderPage lọc khoảng ngày kết hợp từ khóa, giữ bộ lọc khi phân trang và xóa bộ lọc',
      (tester) async {
        configureScreenSize(tester);
        final requests = <Uri>[];

        final mockClient = MockClient((request) async {
          requests.add(request.url);
          final qp = request.url.queryParameters;
          final page = int.tryParse(qp['page'] ?? '1') ?? 1;
          final status = qp['status'];

          if (status == 'Cancelled') {
            return jsonResponse({
              'items': [],
              'totalCount': 0,
              'page': 1,
              'pageSize': 10,
              'totalPages': 0,
              'hasPreviousPage': false,
              'hasNextPage': false,
            });
          }

          if (qp['fromDate'] == '2026-11-01' && qp['toDate'] == '2026-11-25') {
            if (page == 1) {
              return jsonResponse({
                'items': List.generate(
                  12,
                  (i) => sampleOrderJson(
                    id: 100 + i,
                    userFullName: 'Bệnh Nhân Lọc Ngày ${i + 1}',
                    status: 'Pending',
                  ),
                ),
                'totalCount': 13,
                'page': 1,
                'pageSize': 12,
                'totalPages': 2,
                'hasPreviousPage': false,
                'hasNextPage': true,
              });
            }
            return jsonResponse({
              'items': [
                sampleOrderJson(
                  id: 200,
                  userFullName: 'Bệnh Nhân Lọc Ngày Trang 2',
                  status: 'Pending',
                ),
              ],
              'totalCount': 13,
              'page': 2,
              'pageSize': 12,
              'totalPages': 2,
              'hasPreviousPage': true,
              'hasNextPage': false,
            });
          }

          return jsonResponse({
            'items': [
              sampleOrderJson(id: 1, userFullName: 'Đơn Ban Đầu'),
            ],
            'totalCount': 1,
            'page': 1,
            'pageSize': 10,
            'totalPages': 1,
            'hasPreviousPage': false,
            'hasNextPage': false,
          });
        });

        final repo = AdminOrderRepository(
          apiClient: ApiClient(
            client: mockClient,
            baseUrl: 'http://test.api',
            tokenProvider: () async => 'admin_jwt',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AdminOrderPage(
              repository: repo,
              pickDateRange: (context, initialRange) async => DateTimeRange(
                start: DateTime(2026, 11, 1),
                end: DateTime(2026, 11, 25),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đơn Ban Đầu'), findsOneWidget);

        // Nhập từ khóa + submit
        await tester.enterText(
          find.byKey(const ValueKey('admin-order-search-field')),
          'Bệnh Nhân',
        );
        await tester.tap(
          find.byKey(const ValueKey('admin-order-submit-search')),
        );
        await tester.pumpAndSettle();

        // Chọn khoảng ngày
        await tester.tap(
          find.byKey(const ValueKey('admin-order-date-filter-btn')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('admin-order-active-date-chip')),
          findsOneWidget,
        );
        expect(find.text('Từ 01/11/2026 đến 25/11/2026'), findsOneWidget);
        expect(requests.last.queryParameters['keyword'], 'Bệnh Nhân');
        expect(requests.last.queryParameters['fromDate'], '2026-11-01');
        expect(requests.last.queryParameters['toDate'], '2026-11-25');
        expect(find.text('Bệnh Nhân Lọc Ngày 1'), findsOneWidget);

        // Cuộn tải thêm trang 2 -> giữ nguyên keyword + fromDate + toDate
        for (
          var attempt = 0;
          attempt < 5 &&
              !requests.any((u) => u.queryParameters['page'] == '2');
          attempt++
        ) {
          await tester.drag(find.byType(ListView), const Offset(0, -1000));
          await tester.pumpAndSettle();
        }

        final page2Req = requests.firstWhere(
          (u) => u.queryParameters['page'] == '2',
        );
        expect(page2Req.queryParameters['keyword'], 'Bệnh Nhân');
        expect(page2Req.queryParameters['fromDate'], '2026-11-01');
        expect(page2Req.queryParameters['toDate'], '2026-11-25');

        // Xóa lọc ngày riêng lẻ
        await tester.tap(
          find.byKey(const ValueKey('admin-order-clear-date')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('admin-order-active-date-chip')),
          findsNothing,
        );
        expect(requests.last.queryParameters['keyword'], 'Bệnh Nhân');
        expect(requests.last.queryParameters.containsKey('fromDate'), isFalse);
        expect(requests.last.queryParameters.containsKey('toDate'), isFalse);

        // Chọn trạng thái Đã hủy (trả về rỗng) -> bấm Xóa bộ lọc reset toàn bộ
        final cancelledChip = find.byKey(
          const ValueKey('order-filter-Cancelled'),
        );
        await tester.ensureVisible(cancelledChip);
        await tester.pumpAndSettle();
        await tester.tap(cancelledChip);
        await tester.pumpAndSettle();

        expect(
          find.text('Không tìm thấy đơn đặt lịch phù hợp với bộ lọc hiện tại.'),
          findsOneWidget,
        );
        final resetBtn = find.byKey(
          const ValueKey('admin-order-reset-filters'),
        );
        expect(resetBtn, findsOneWidget);

        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(requests.last.queryParameters, {'page': '1', 'pageSize': '10'});
        expect(find.text('Đơn Ban Đầu'), findsOneWidget);
      },
    );
  });
}
