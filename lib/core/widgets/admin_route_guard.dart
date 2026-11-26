import 'package:flutter/material.dart';
import '../../helpers/session_helper.dart';
import '../theme/app_theme.dart';

/// Bảo vệ các màn hình quản trị (/admin/*) ở tầng giao diện.
/// Luôn kiểm tra claim ADMIN từ JWT hợp lệ còn hạn thông qua SessionHepler.isAdmin().
class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({
    super.key,
    required this.child,
    this.isAdminChecker,
  });

  final Widget child;
  final Future<bool> Function()? isAdminChecker;

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  bool _isChecking = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant AdminRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdminChecker != widget.isAdminChecker) {
      setState(() => _isChecking = true);
      _check();
    }
  }

  Future<void> _check() async {
    final authorized = await (widget.isAdminChecker ?? SessionHepler.isAdmin)();
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _isAuthorized = authorized;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthorized) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị hệ thống')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Color(0xffef4444),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn không có quyền truy cập',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Chỉ Quản trị viên (ADMIN) mới được phép truy cập khu vực này.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
