import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/core/network/api_client.dart';
import 'package:medical_appointment_app/models/patient_profile.dart';
import 'package:medical_appointment_app/repositories/patient_profile_repository.dart';
import 'package:medical_appointment_app/screens/patient_profiles/patient_profiles_page.dart';

void main() {
  testWidgets('Chọn người thân để tiếp tục đến chuyên khoa', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const self = PatientProfile(
      id: 1,
      fullName: 'Nguyễn Minh An',
      relationship: 'Bản thân',
      phone: '0912345678',
    );
    const relative = PatientProfile(
      id: 2,
      fullName: 'Nguyễn Minh Châu',
      relationship: 'Con',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: const PatientProfilesPage(
          forBooking: true,
          profiles: [self, relative],
        ),
        routes: {
          '/departments': (context) {
            expect(ModalRoute.of(context)?.settings.arguments, same(relative));
            return const Scaffold(body: Text('Chọn chuyên khoa'));
          },
        },
      ),
    );

    expect(find.text('091****678'), findsOneWidget);
    expect(find.text('0912345678'), findsNothing);
    await tester.tap(find.text('Thêm hồ sơ mới'));
    await tester.pumpAndSettle();
    expect(find.text('Họ và tên'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Châu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(relative.fullName));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chuyên khoa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thêm, sửa và vuốt xóa hồ sơ qua API', (tester) async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') return http.Response('[]', 200);
      if (request.method == 'DELETE') return http.Response('', 204);

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['relationship'], 'Bản thân');
      expect(body['identityCardNumber'], '012345678901');
      expect(body['gender'], 'Nữ');
      expect(body['dateOfBirth'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      return http.Response.bytes(
        utf8.encode(jsonEncode({...body, 'id': 3})),
        request.method == 'POST' ? 201 : 200,
      );
    });
    addTearDown(client.close);
    final repository = PatientProfileRepository(
      apiClient: ApiClient(
        client: client,
        baseUrl: 'http://test.api',
        tokenProvider: () async => 'test-token',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: PatientProfilesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có hồ sơ bệnh nhân.'), findsOneWidget);

    await tester.tap(find.byTooltip('Thêm hồ sơ mới'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Minh An',
    );
    await tester.tap(find.text('Chọn ngày sinh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giới tính'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nữ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CCCD'),
      '012345678901',
    );
    final relationship = find.widgetWithText(TextFormField, 'Mối quan hệ');
    await tester.ensureVisible(relationship);
    await tester.enterText(relationship, 'Bản thân');
    final save = find.widgetWithText(FilledButton, 'Lưu hồ sơ');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final card = find.widgetWithText(ListTile, 'Minh An');
    expect(card, findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('012345678901'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Minh Anh',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Minh Anh'), findsOneWidget);

    await tester.drag(find.byType(Dismissible), const Offset(-650, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Minh Anh'), findsOneWidget);
    await tester.drag(find.byType(Dismissible), const Offset(-650, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có hồ sơ bệnh nhân.'), findsOneWidget);
    expect(requests, [
      'GET /api/patient-profiles',
      'POST /api/patient-profiles',
      'PUT /api/patient-profiles/3',
      'DELETE /api/patient-profiles/3',
    ]);
  });
}
