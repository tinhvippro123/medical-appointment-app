import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/account/change_password_page.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/admin/departments/department_admin_page.dart';
import 'screens/admin/roles/role_admin_page.dart';
import 'screens/admin/users/user_admin_page.dart';
import 'screens/auth/auth_gate_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/cart/cart_page.dart';
import 'screens/home/home_page.dart';

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
        '/admin': (_) => const AdminDashboardPage(),
        '/admin/users': (_) => const UserAdminPage(),
        '/admin/roles': (_) => const RoleAdminPage(),
        '/admin/departments': (_) => const DepartmentAdminPage(),
        '/change-password': (_) => const ChangePasswordPage(),
      },
      home: home,
    );
  }
}
