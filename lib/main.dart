import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'models/department.dart';
import 'models/doctor.dart';
import 'models/patient_profile.dart';
import 'screens/account/change_password_page.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/departments/department_admin_page.dart';
import 'screens/admin/doctors/doctor_admin_page.dart';
import 'screens/admin/roles/role_admin_page.dart';
import 'screens/admin/users/user_admin_page.dart';
import 'screens/auth/auth_gate_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/booking/booking_page.dart';
import 'screens/cart/cart_page.dart';
import 'screens/departments/department_list_page.dart';
import 'screens/doctors/detail/doctor_detail_page.dart';
import 'screens/doctors/search/doctor_search_page.dart';
import 'screens/home/home_page.dart';
import 'screens/patient_profiles/patient_profiles_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    const configuredRoute = String.fromEnvironment('INITIAL_ROUTE');
    return MaterialApp(
      title: 'Y tế Hiệp Phước',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: home == null && configuredRoute.isNotEmpty
          ? configuredRoute
          : null,
      routes: {
        if (home == null) '/': (_) => const AuthGatePage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/cart': (_) => const CartPage(),
        '/booking/patient': (_) => const PatientProfilesPage(forBooking: true),
        '/departments': (context) {
          final patient = ModalRoute.of(context)?.settings.arguments;
          return DepartmentListPage(
            patient: patient is PatientProfile ? patient : null,
          );
        },
        '/admin': (_) => const AdminDashboardPage(),
        '/admin/users': (_) => const UserAdminPage(),
        '/admin/roles': (_) => const RoleAdminPage(),
        '/admin/departments': (_) => const DepartmentAdminPage(),
        '/admin/doctors': (_) => const DoctorAdminPage(),
        '/doctors': (context) {
          final argument = ModalRoute.of(context)?.settings.arguments;
          return DoctorSearchPage(
            browse: true,
            department: argument is Department ? argument : null,
          );
        },
        '/doctors/search': (context) {
          final argument = ModalRoute.of(context)?.settings.arguments;
          return DoctorSearchPage(
            initialKeyword: argument is String ? argument : null,
            department: argument is Department ? argument : null,
          );
        },
        '/doctors/detail': (context) {
          final doctorId = ModalRoute.of(context)?.settings.arguments;
          return DoctorDetailPage(
            doctorId: doctorId is int
                ? doctorId
                : int.tryParse(doctorId?.toString() ?? ''),
          );
        },
        '/booking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int? doctorId;
          if (args is int) {
            doctorId = args;
          } else if (args is String) {
            doctorId = int.tryParse(args);
          } else if (args is Doctor) {
            doctorId = args.id;
          }
          return BookingPage(doctorId: doctorId);
        },
        '/change-password': (_) => const ChangePasswordPage(),
      },
      home: home,
    );
  }
}
