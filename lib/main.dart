import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/admin/departments/department_admin_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/cart/cart_page.dart';

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
        if (home == null) '/': (_) => const LoginPage(),
        '/cart': (_) => const CartPage(),
        '/admin/departments': (_) => const DepartmentAdminPage(),
      },
      home: home,
    );
  }
}
