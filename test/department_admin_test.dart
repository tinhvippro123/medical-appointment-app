import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medical_appointment_app/repositories/department_repository.dart';
import 'package:medical_appointment_app/screens/admin/departments/department_admin_page.dart';

Map<String, dynamic> department(String name) => {
  'id': 1,
  'name': name,
  'description': 'Khám và tư vấn',
  'imageUrl': null,
};
void main() {
  testWidgets('Tải lại khi API lỗi rồi phục hồi', (tester) async {
    var attempts = 0;
    final repo = DepartmentRepository(baseUrl: 'http://localhost', token: () async => null, client: MockClient((request) async {
      attempts++;
      if (attempts == 1) throw Exception('network');
      return http.Response.bytes(utf8.encode(jsonEncode([department('Nội tổng quát')])), 200);
    }));
    await tester.pumpWidget(MaterialApp(home: DepartmentAdminPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nội tổng quát'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Danh sách, prefill, xác nhận xóa và lỗi khoa còn bác sĩ', (
    tester,
  ) async {
    var deletes = 0;
    final repo = DepartmentRepository(
      baseUrl: 'http://localhost',
      token: () async => 'token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        if (request.method == 'DELETE') {
          deletes++;
          return http.Response(
            jsonEncode({'errorCode': 'DEPARTMENT_HAS_DOCTORS'}),
            400,
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode([department('Nội tổng quát')])),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: DepartmentAdminPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nội tổng quát'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Nội tổng quát'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xóa Nội tổng quát'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.text('Khoa còn bác sĩ, không thể xóa'), findsOneWidget);
    expect(find.text('Nội tổng quát'), findsOneWidget);
  });
  test('Lưu thông tin, tải file và lưu URL ảnh đúng endpoint', () async {
    final requests = <http.Request>[];
    final repo = DepartmentRepository(
      baseUrl: 'http://localhost',
      token: () async => null,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(jsonEncode(department('Tim mạch'))),
          200,
        );
      }),
    );
    final saved = await repo.save(name: 'Tim mạch', description: 'Mô tả');
    expect(jsonDecode(requests.first.body)['name'], 'Tim mạch');
    await repo.upload(saved.id, [1, 2, 3], 'photo.png');
    expect(requests.last.url.path, '/api/departments/1/image');
    expect(
      requests.last.headers['content-type'],
      contains('multipart/form-data'),
    );
    expect(requests.last.body, contains('name="file"'));
    const imageUrl = 'https://example.com/department.png';
    await repo.setImageUrl(saved.id, imageUrl);
    expect(requests.last.method, 'POST');
    expect(requests.last.url.path, '/api/departments/1/image/url');
    expect(jsonDecode(requests.last.body), {'imageUrl': imageUrl});
    await repo.save(id: 1, name: 'Tim mạch', description: 'Sửa');
    expect(requests.last.method, 'PUT');
  });
}

