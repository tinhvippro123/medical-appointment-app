import 'package:flutter/material.dart';
import '../../helpers/session_helper.dart';
import '../admin/admin_dashboard_page.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    final user = await SessionHepler.getCurrentUser();
    if (!mounted) {
      return;
    }

    final Widget target;
    if (user == null) {
      target = const LoginPage();
    } else if (user.isAdmin) {
      target = AdminDashboardPage(currentUser: user);
    } else {
      target = const HomePage();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
