import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Y tế Hiệp Phước',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const HomePage(),
  );
}
