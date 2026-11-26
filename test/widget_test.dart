import 'package:flutter/material.dart';
import 'package:medical_appointment_app/screens/home/widgets/healthcare_functions_panel.dart';
import 'package:medical_appointment_app/screens/home/widgets/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_appointment_app/screens/home/function_order_store.dart';
import 'package:medical_appointment_app/screens/home/function_order_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_appointment_app/main.dart';
import 'package:medical_appointment_app/screens/account/account_page.dart';
import 'package:medical_appointment_app/screens/booking/order_history_page.dart';
import 'package:medical_appointment_app/screens/departments/department_list_page.dart';
import 'package:medical_appointment_app/screens/home/home_page.dart';
import 'package:medical_appointment_app/screens/home/usage_guide_page.dart';
import 'package:medical_appointment_app/screens/home/widgets/home_header.dart';
import 'package:medical_appointment_app/screens/patient_profiles/patient_profiles_page.dart';

void main() {
  final homeBooking = find.descendant(
    of: find.byType(HealthcareFunctionsPanel),
    matching: find.text('Đặt khám'),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Menu dưới có Trang chủ ở giữa và chuyển đủ 5 mục', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(home: HomePage()));
    await tester.pumpAndSettle();
    final bookingTab = find.byKey(const ValueKey('bottom-nav-0'));
    expect(
      find.descendant(of: bookingTab, matching: find.text('Đặt khám')),
      findsOneWidget,
    );
    expect(find.text('Hóa đơn'), findsNothing);
    await tester.tap(bookingTab);
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-3')));
    await tester.pumpAndSettle();
    expect(find.byType(PatientProfilesPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderHistoryPage).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-4')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountPage).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.text('XÃ HIỆP PHƯỚC'),
      ),
      findsOneWidget,
    );
    final profileShortcut = find.text('Hồ sơ\nbệnh nhân');
    await tester.ensureVisible(profileShortcut);
    await tester.tap(profileShortcut);
    await tester.pumpAndSettle();
    expect(find.byType(PatientProfilesPage).hitTestable(), findsOneWidget);
    expect(find.byType(FeaturePlaceholder), findsNothing);
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
    await tester.pumpWidget(const MyApp(home: HomePage()));
    await tester.pumpAndSettle();
    expect(homeBooking, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tìm kiếm không dấu và sắp xếp chức năng', (tester) async {
    await tester.pumpWidget(const MyApp(home: HomePage()));
    await tester.tap(find.byTooltip('Tìm kiếm chức năng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hoa don');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HealthcareFunctionsPanel),
        matching: find.text('Hóa đơn'),
      ),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'ho so benh nhan');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(HealthcareFunctionsPanel),
        matching: find.text('Hồ sơ\nbệnh nhân'),
      ),
      findsOneWidget,
    );
    expect(homeBooking, findsNothing);
    await tester.tap(find.byTooltip('Đóng tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sắp xếp chức năng'));
    await tester.pumpAndSettle();
    expect(find.byType(FunctionOrderPage), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Đặt khám')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('Hồ sơ\nbệnh nhân')));
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

    await tester.pumpWidget(const MyApp(home: HomePage()));
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
    await tester.pumpWidget(const MyApp(home: HomePage()));
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
    await tester.ensureVisible(homeBooking);
    await tester.tap(homeBooking);
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thông tin trung tâm'));
    expect(find.text('Giờ làm việc'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Trang chủ mở hướng dẫn sử dụng và đi tiếp đến đặt khám', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(home: HomePage()));
    await tester.pumpAndSettle();
    final guide = find.text('Hướng dẫn\nsử dụng');
    await tester.ensureVisible(guide);
    await tester.tap(guide);
    await tester.pumpAndSettle();
    expect(find.byType(UsageGuidePage), findsOneWidget);

    await tester.tap(find.text('Đặt lịch khám'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chọn chuyên khoa, ngày khám'), findsOneWidget);

    final booking = find.text('Đặt khám ngay');
    await tester.ensureVisible(booking);
    await tester.tap(booking);
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
  });
  testWidgets('Ô Bác sĩ mở danh sách chuyên khoa để xem bác sĩ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      FunctionOrderStore.key: ['Bác sĩ'],
    });
    await tester.pumpWidget(const MyApp(home: HomePage()));
    await tester.pumpAndSettle();
    final doctors = find.text('Bác sĩ');
    final doctorCard = tester.widget<HealthcareServiceCard>(
      find.ancestor(of: doctors, matching: find.byType(HealthcareServiceCard)),
    );
    expect(doctorCard.service.asset, 'assets/images/services/doctor.png');
    expect((await FunctionOrderStore().load()).first.title, 'Bác sĩ');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(doctors);
    await tester.tap(doctors);
    await tester.pumpAndSettle();

    final departments = tester.widget<DepartmentListPage>(
      find.byType(DepartmentListPage),
    );
    expect(departments.patient, isNull);
    expect(find.text('Danh sách chuyên khoa'), findsOneWidget);
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
          home: const MyApp(home: HomePage()),
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
