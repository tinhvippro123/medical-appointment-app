import 'package:flutter/material.dart';
import 'package:medical_appointment_app/screens/home/widgets/healthcare_functions_panel.dart';
import 'package:medical_appointment_app/screens/home/widgets/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_appointment_app/services/function_order_store.dart';
import 'package:medical_appointment_app/screens/home/function_order_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_appointment_app/main.dart';
import 'package:medical_appointment_app/screens/home/widgets/home_header.dart';

void main() {
  testWidgets('Menu dưới có Trang chủ ở giữa và chuyển đủ 5 mục', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    for (final index in [0, 1, 3, 4]) {
      await tester.tap(find.byKey(ValueKey('bottom-nav-$index')));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureMessage).hitTestable(), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.text('XÃ HIỆP PHƯỚC'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Lưới chức năng không tạo kích thước âm khi viewport bằng 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 0,
            child: HealthcareServiceGrid(onSelected: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Đặt khám'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Tìm kiếm không dấu và sắp xếp chức năng', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Tìm kiếm chức năng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hoa don');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HealthcareFunctionsPanel),
        matching: find.text('Hóa đơn'),
      ),
      findsOneWidget,
    );
    expect(find.text('Đặt khám'), findsNothing);
    await tester.tap(find.byTooltip('Đóng tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sắp xếp chức năng'));
    await tester.pumpAndSettle();
    expect(find.byType(FunctionOrderPage), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Đặt khám')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('Hóa đơn')));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Lịch sử\nđặt khám')).dx,
      lessThan(tester.getTopLeft(find.text('Đặt khám')).dx),
    );
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(FunctionOrderPage), findsNothing);
    expect(
      (await FunctionOrderStore().load()).first.title,
      'Lịch sử\nđặt khám',
    );
    await tester.tap(find.byTooltip('Sắp xếp chức năng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cài đặt lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect((await FunctionOrderStore().load()).first.title, 'Đặt khám');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Home renders semantics during scroll and navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thông tin trung tâm'));
    expect(find.text('Giờ làm việc'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
  testWidgets('Dịch vụ và thông tin trung tâm hiển thị đúng', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.text('XÃ HIỆP PHƯỚC'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(FeaturePlaceholder), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đặt khám'));
    await tester.tap(find.text('Đặt khám'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt khám'), findsNWidgets(2));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thông tin trung tâm'));
    expect(find.text('Giờ làm việc'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('Không tràn bố cục ở chiều rộng $width và chữ lớn', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const MyApp(),
        ),
      );
      await tester.pump();
      // Report framework layout errors at test completion.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pump();
      // Report framework layout errors at test completion.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
