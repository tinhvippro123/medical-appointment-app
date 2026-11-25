import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/helpers/local_database_helper.dart';
import 'package:medical_appointment_app/helpers/session_helper.dart';
import 'package:medical_appointment_app/models/user_role_models.dart';
import 'package:medical_appointment_app/repositories/auth_repository.dart';
import 'package:medical_appointment_app/repositories/role_repository.dart';
import 'package:medical_appointment_app/repositories/user_repository.dart';
import 'package:medical_appointment_app/screens/account/account_page.dart';
import 'package:medical_appointment_app/screens/account/change_password_page.dart';
import 'package:medical_appointment_app/screens/admin/admin_dashboard_page.dart';
import 'package:medical_appointment_app/screens/admin/roles/role_admin_page.dart';
import 'package:medical_appointment_app/screens/admin/users/user_admin_page.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'package:medical_appointment_app/screens/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

String buildJwt({
  required int userId,
  required String fullName,
  required String phone,
  required String roleKey,
  DateTime? expiresAt,
}) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final exp =
      ((expiresAt ?? DateTime.now().add(const Duration(days: 7)))
                  .toUtc()
                  .millisecondsSinceEpoch /
              1000)
          .floor();
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier':
            '$userId',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/mobilephone':
            phone,
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name': fullName,
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role':
            roleKey,
        'exp': exp,
      }),
    ),
  );
  return '$header.$payload.sig';
}

Map<String, dynamic> roleJson({
  required int id,
  required String key,
  required String name,
  String? description,
  int userCount = 0,
}) => {
  'id': id,
  'key': key,
  'name': name,
  'description': description,
  'userCount': userCount,
};

Map<String, dynamic> userJson({
  required int id,
  required String fullName,
  required String phone,
  String? email,
  int roleId = 2,
  String roleKey = 'PATIENT',
  String roleName = 'Bệnh nhân',
  bool isActive = true,
}) => {
  'id': id,
  'fullName': fullName,
  'phone': phone,
  'email': email,
  'roleId': roleId,
  'roleKey': roleKey,
  'roleName': roleName,
  'isActive': isActive,
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabaseHelper.resetForTest();
  });

  group('SQLite LocalDatabaseHelper & JWT Session', () {
    test('SQLite lưu session, cache roles và cache users hoạt động đúng', () async {
      await LocalDatabaseHelper.useInMemoryForTest();
      addTearDown(LocalDatabaseHelper.resetForTest);

      const user = SessionUser(
        userId: 1,
        fullName: 'Admin Hệ Thống',
        phone: '0900000001',
        roleKey: 'ADMIN',
      );
      await LocalDatabaseHelper.saveSession(user, 'jwt-token-123');
      final session = await LocalDatabaseHelper.getSession();
      expect(session, isNotNull);
      expect(session!.user.userId, 1);
      expect(session.user.fullName, 'Admin Hệ Thống');
      expect(session.user.isAdmin, isTrue);
      expect(session.token, 'jwt-token-123');

      await LocalDatabaseHelper.cacheRoles([
        RoleItem.fromJson(roleJson(id: 1, key: 'ADMIN', name: 'Quản trị', userCount: 1)),
        RoleItem.fromJson(roleJson(id: 2, key: 'PATIENT', name: 'Bệnh nhân', userCount: 4)),
      ]);
      final cachedRoles = await LocalDatabaseHelper.getCachedRoles();
      expect(cachedRoles.length, 2);
      expect(cachedRoles.first.key, 'ADMIN');

      await LocalDatabaseHelper.cacheUsers([
        UserItem.fromJson(
          userJson(id: 10, fullName: 'Nguyễn Văn B', phone: '0912345678'),
        ),
      ]);
      final cachedUsers = await LocalDatabaseHelper.getCachedUsers();
      expect(cachedUsers.length, 1);
      expect(cachedUsers.first.phone, '0912345678');

      await LocalDatabaseHelper.clearSession();
      expect(await LocalDatabaseHelper.getSession(), isNull);
    });

    test('SessionHepler giải mã JWT claims ADMIN/PATIENT và kiểm tra hết hạn', () async {
      final adminToken = buildJwt(
        userId: 1,
        fullName: 'Quản Trị',
        phone: '0900000001',
        roleKey: 'ADMIN',
      );
      await SessionHepler.saveToken(adminToken);
      expect(await SessionHepler.isLoggedIn(), isTrue);
      expect(await SessionHepler.isAdmin(), isTrue);
      final current = await SessionHepler.getCurrentUser();
      expect(current?.fullName, 'Quản Trị');

      final expiredToken = buildJwt(
        userId: 2,
        fullName: 'Hết Hạn',
        phone: '0900000002',
        roleKey: 'PATIENT',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await SessionHepler.saveToken(expiredToken);
      expect(await SessionHepler.getCurrentUser(), isNull);
      expect(await SessionHepler.isLoggedIn(), isFalse);
    });
  });

  group('RoleAdminPage', () {
    testWidgets('Hiển thị vai trò mặc định, tạo vai trò mới và báo lỗi ROLE_IN_USE', (
      tester,
    ) async {
      final roles = <Map<String, dynamic>>[
        roleJson(id: 1, key: 'ADMIN', name: 'Quản trị viên', userCount: 1),
        roleJson(id: 2, key: 'PATIENT', name: 'Bệnh nhân', userCount: 5),
        roleJson(
          id: 3,
          key: 'STAFF',
          name: 'Nhân viên',
          description: 'Tiếp tân phòng khám',
          userCount: 2,
        ),
      ];

      final repo = RoleRepository(
        baseUrl: 'http://localhost',
        token: () async => 'admin-jwt',
        enableCache: false,
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.path == '/api/roles') {
            return http.Response.bytes(utf8.encode(jsonEncode(roles)), 200);
          }
          if (request.method == 'POST' && request.url.path == '/api/roles') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final created = roleJson(
              id: 4,
              key: body['key'] as String,
              name: body['name'] as String,
              description: body['description'] as String?,
            );
            roles.add(created);
            return http.Response.bytes(utf8.encode(jsonEncode(created)), 201);
          }
          if (request.method == 'DELETE' && request.url.path == '/api/roles/3') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'statusCode': 400,
                  'errorCode': 'ROLE_IN_USE',
                  'message': 'Vai trò này đang được gán cho người dùng, không thể xóa.',
                }),
              ),
              400,
            );
          }
          return http.Response('', 404);
        }),
      );

      await tester.pumpWidget(MaterialApp(home: RoleAdminPage(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Quản trị viên'), findsOneWidget);
      expect(find.text('Mặc định'), findsNWidgets(2));
      expect(find.text('2 người dùng'), findsOneWidget);

      // Xoa vai tro mac dinh ADMIN bi khoa nut
      final adminDelete = tester.widget<IconButton>(
        find
            .byWidgetPredicate(
              (w) =>
                  w is IconButton &&
                  w.tooltip == 'Không thể xóa vai trò mặc định',
            )
            .first,
      );
      expect(adminDelete.onPressed, isNull);

      // Thu xoa vai tro STAFF -> hien loi ROLE_IN_USE tu backend
      await tester.tap(find.byTooltip('Xóa Nhân viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vai trò này đang được gán cho người dùng, không thể xóa.'),
        findsOneWidget,
      );

      // Mo dialog them vai tro moi
      await tester.tap(find.text('Thêm vai trò'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã vai trò (Key) *'),
        'doctor',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tên vai trò *'),
        'Bác sĩ',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(find.text('DOCTOR'), findsOneWidget);
      expect(find.text('Bác sĩ'), findsOneWidget);
    });
  });

  group('UserAdminPage', () {
    testWidgets('Hiển thị phân trang, khóa tự thao tác với bản thân và đổi trạng thái', (
      tester,
    ) async {
      final requestedUrls = <Uri>[];
      final users = [
        userJson(
          id: 1,
          fullName: 'Admin Tính',
          phone: '0900000001',
          roleId: 1,
          roleKey: 'ADMIN',
          roleName: 'Quản trị viên',
          isActive: true,
        ),
        userJson(
          id: 2,
          fullName: 'Bệnh Nhân An',
          phone: '0912345678',
          roleId: 2,
          roleKey: 'PATIENT',
          roleName: 'Bệnh nhân',
          isActive: true,
        ),
      ];

      final roleRepo = RoleRepository(
        baseUrl: 'http://localhost',
        token: () async => 'admin-jwt',
        enableCache: false,
        client: MockClient((_) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                roleJson(id: 1, key: 'ADMIN', name: 'Quản trị viên'),
                roleJson(id: 2, key: 'PATIENT', name: 'Bệnh nhân'),
              ]),
            ),
            200,
          );
        }),
      );

      final userRepo = UserRepository(
        baseUrl: 'http://localhost',
        token: () async => 'admin-jwt',
        enableCache: false,
        client: MockClient((request) async {
          requestedUrls.add(request.url);
          if (request.method == 'GET' && request.url.path == '/api/users') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'items': users,
                  'totalCount': 2,
                  'page': 1,
                  'pageSize': 10,
                  'totalPages': 1,
                  'hasPreviousPage': false,
                  'hasNextPage': false,
                }),
              ),
              200,
            );
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/api/users/2/status') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            users[1] = {
              ...users[1],
              'isActive': body['isActive'],
            };
            return http.Response.bytes(utf8.encode(jsonEncode(users[1])), 200);
          }
          return http.Response('', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UserAdminPage(
            userRepository: userRepo,
            roleRepository: roleRepo,
            currentUserId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Tính'), findsOneWidget);
      expect(find.text('Bạn'), findsOneWidget);
      expect(find.text('Bệnh Nhân An'), findsOneWidget);

      // Nut khoa tai khoan ban than phai bi vo hieu hoa
      final selfSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(selfSwitch.onChanged, isNull);

      // Toggle trang thai nguoi dung thu 2
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(
        requestedUrls.any((u) => u.path == '/api/users/2/status'),
        isTrue,
      );
      expect(find.text('Đã khóa'), findsWidgets);
    });
  });

  group('Role-based Routing, AccountPage & ChangePasswordPage', () {
    testWidgets('AccountPage hiện nút Quản trị cho ADMIN và ẩn với PATIENT', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccountPage(
              currentUser: SessionUser(
                userId: 1,
                fullName: 'Admin',
                phone: '0900000001',
                roleKey: 'ADMIN',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mở trang Quản trị (Admin)'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccountPage(
              currentUser: SessionUser(
                userId: 2,
                fullName: 'Bệnh nhân A',
                phone: '0912345678',
                roleKey: 'PATIENT',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mở trang Quản trị (Admin)'), findsNothing);
    });

    testWidgets('ChangePasswordPage validate và gọi PUT /api/auth/change-password', (
      tester,
    ) async {
      String? capturedBody;
      final authRepo = AuthRepository(
        baseUrl: 'http://localhost',
        token: () async => 'user-jwt',
        client: MockClient((request) async {
          if (request.method == 'PUT' &&
              request.url.path == '/api/auth/change-password') {
            capturedBody = request.body;
            return http.Response.bytes(
              utf8.encode(jsonEncode({'message': 'Đổi mật khẩu thành công'})),
              200,
            );
          }
          return http.Response('', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: ChangePasswordPage(authRepository: authRepo)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu hiện tại *'),
        '123456',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới *'),
        '654321',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới *'),
        '654321',
      );
      await tester.tap(find.text('Cập nhật mật khẩu'));
      await tester.pumpAndSettle();

      expect(capturedBody, isNotNull);
      expect(jsonDecode(capturedBody!)['newPassword'], '654321');
    });

    testWidgets('LoginPage điều hướng ADMIN vào AdminDashboardPage', (
      tester,
    ) async {
      final adminAuthRepo = AuthRepository(
        baseUrl: 'http://localhost',
        client: MockClient((_) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'token': buildJwt(
                  userId: 1,
                  fullName: 'Admin Tính',
                  phone: '0900000001',
                  roleKey: 'ADMIN',
                ),
                'message': 'Đăng nhập thành công',
              }),
            ),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: LoginPage(authRepository: adminAuthRepo)),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại'),
        '0900000001',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'Admin@123',
      );
      await tester.tap(find.text('ĐĂNG NHẬP'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardPage), findsOneWidget);
    });

    testWidgets('LoginPage điều hướng PATIENT vào HomePage', (tester) async {
      final patientAuthRepo = AuthRepository(
        baseUrl: 'http://localhost',
        client: MockClient((_) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'token': buildJwt(
                  userId: 2,
                  fullName: 'Bệnh Nhân',
                  phone: '0912345678',
                  roleKey: 'PATIENT',
                ),
                'message': 'Đăng nhập thành công',
              }),
            ),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: LoginPage(authRepository: patientAuthRepo)),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại'),
        '0912345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        '123456',
      );
      await tester.tap(find.text('ĐĂNG NHẬP'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
