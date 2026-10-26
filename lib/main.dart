import 'package:flutter/material.dart';
import 'package:medical_appointment_app/screens/auth/login_page.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  final Widget? home;
  const MyApp({super.key, this.home});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Y tế Hiệp Phước',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: home ?? const LoginPage(),
  );
}
